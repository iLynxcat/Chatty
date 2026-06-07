use chattyproto::*;

use std::{
    collections::HashSet,
    sync::{
        Arc, LazyLock,
        atomic::{self, AtomicU32, Ordering::Relaxed},
    },
};

use tokio::{
    io::{self, AsyncBufReadExt, AsyncWriteExt, BufReader},
    net::{TcpListener, TcpStream},
    sync::{RwLock, broadcast, mpsc},
    task::JoinHandle,
};

static UID_COUNTER: atomic::AtomicU32 = atomic::AtomicU32::new(1);

pub static CHANNELS: LazyLock<RwLock<HashSet<String>>> =
    LazyLock::new(|| RwLock::new(HashSet::from(["general".into(), "meta".into()])));

const BIND: &str = "100.122.23.64:4307";

/// All messages are sent through this bus.
/// (in:channel from:sender :body)
pub static BROADCAST_CHANNEL: LazyLock<broadcast::Sender<OutMsg>> =
    LazyLock::new(|| broadcast::channel(64).0);

trait SendOut {
    async fn send(
        &self,
        sender: &mpsc::Sender<String>,
    ) -> Result<(), mpsc::error::SendError<String>>;
}

impl SendOut for OutMsg {
    async fn send(
        &self,
        sender: &mpsc::Sender<String>,
    ) -> Result<(), mpsc::error::SendError<String>> {
        sender.send(format!("{}\n", self.to_message())).await
    }
}

#[tokio::main]
async fn main() -> tokio::io::Result<()> {
    let mut args = std::env::args();
    _ = args.next(); // skip the first argument

    let listener = TcpListener::bind(BIND).await?;
    println!("ok, listening on {BIND}");

    loop {
        let (stream, _) = listener.accept().await?;
        tokio::spawn(async move {
            if let Err(e) = run_session(stream).await {
                eprintln!("client error: {e}")
            }
        });
    }
}

async fn run_session(stream: TcpStream) -> std::io::Result<()> {
    let uid_cell: Arc<AtomicU32> = Arc::new(AtomicU32::new(u32::MAX));
    let mut nickname: String;
    let active_channel: Arc<RwLock<Option<String>>> = Arc::new(RwLock::new(None));

    let (read, write) = stream.into_split();
    let (out_tx, out_rx) = mpsc::channel::<String>(64);

    {
        let uid_cell = uid_cell.clone();
        let active_channel = active_channel.clone();

        // send messages to out_tx, this forwards them to the client via writer
        tokio::spawn(async move {
            let mut write = write;
            let mut rx = out_rx;
            let mut broadcast_rx = BROADCAST_CHANNEL.subscribe();

            loop {
                tokio::select! {
                    Some(line) = rx.recv() => {
                        if write.write_all(line.as_bytes()).await.is_err() { break; }
                    }
                    Ok(msg) = broadcast_rx.recv() => {
                        if let OutMsg::Message(channel, ..) = &msg {
                            if channel == &active_channel.read().await.clone().unwrap_or("".to_string()) {
                                if write.write_all(format!("{}\n", msg.to_message()).as_bytes()).await.is_err() { break; }
                            }
                        } else if let OutMsg::Status(_, status, status_uid) = &msg {
                                if status == "connected" && uid_cell.load(Relaxed) == *status_uid { continue; }
                            if status == "disconnected" && uid_cell.load(Relaxed) == *status_uid { continue; }
                            if write.write_all(format!("{}\n", msg.to_message()).as_bytes()).await.is_err() { break; }
                        } else {
                            if write.write_all(format!("{}\n", msg.to_message()).as_bytes()).await.is_err() { break; }
                        }
                    }
                    else => break,
                }
            }
        });
    }

    let mut reader = BufReader::new(read);
    let mut line = String::new();
    let mut sub_handle: Option<JoinHandle<()>> = None;

    OutMsg::Welcome("Call /LOGIN <name> to connect.".into())
        .send(&out_tx)
        .await
        .map_err(|msg| io::Error::other(format!("failed to send welcome message: {}", msg)))?;

    {
        let mut result = None;
        while reader.read_line(&mut line).await.unwrap_or(0) != 0 {
            let name_result = Cmd::try_from(line.trim());
            if let Ok(Cmd::Login(name)) = name_result {
                result = Some((UID_COUNTER.fetch_add(1, atomic::Ordering::Relaxed), name));
                break;
            } else if let Err(err) = name_result {
                OutMsg::Error(err.to_string())
                    .send(&out_tx)
                    .await
                    .map_err(|msg| {
                        io::Error::other(format!("sending error message failed... uh oh! {msg}"))
                    })?;
            }

            OutMsg::Welcome("Call /LOGIN <name> to connect.".into())
                .send(&out_tx)
                .await
                .map_err(|msg| {
                    io::Error::other(format!("failed to send welcome message: {}", msg))
                })?;

            line.clear();
        }

        let Some(identity) = result else {
            return Ok(());
        };

        let (uid, name) = identity;
        nickname = name;
        uid_cell.store(uid, atomic::Ordering::Relaxed);
    };

    println!("user {} joined as {nickname}", uid_cell.load(Relaxed));
    *active_channel.write().await = Some("general".to_string());

    line.clear();

    OutMsg::Connected(nickname.clone(), uid_cell.load(Relaxed))
        .send(&out_tx)
        .await
        .ok();
    OutMsg::Ping(active_channel.read().await.clone().unwrap())
        .send(&out_tx)
        .await
        .ok();
    BROADCAST_CHANNEL
        .send(OutMsg::Status(
            nickname.clone(),
            "connected".into(),
            uid_cell.load(Relaxed),
        ))
        .ok();

    while reader.read_line(&mut line).await.unwrap_or(0) != 0 {
        let uid = uid_cell.load(Relaxed);

        let trimmed = line.trim().to_string();
        line.clear();

        let response: Option<OutMsg> = match Cmd::try_from(trimmed.as_str()) {
            Ok(cmd) => match cmd {
                Cmd::Send(chan, msg) if chan == "{current}" => {
                    let chan = active_channel.read().await.clone().unwrap();
                    BROADCAST_CHANNEL
                        .send(OutMsg::Message(chan, nickname.clone(), uid, msg))
                        .ok();
                    None
                }
                Cmd::Send(chan, msg) => {
                    BROADCAST_CHANNEL
                        .send(OutMsg::Message(chan, nickname.clone(), uid, msg))
                        .ok();
                    None
                }
                Cmd::Switch(chan) => {
                    if !CHANNELS.read().await.contains(&chan) {
                        *active_channel.write().await = None;
                        Some(OutMsg::Warning("no such channel.".into()))
                    } else {
                        *active_channel.write().await = Some(chan.clone());
                        Some(OutMsg::Ping(chan))
                    }
                }
                Cmd::Identify() => Some(OutMsg::Connected(nickname.clone(), uid)),
                Cmd::Login(..) => Some(OutMsg::Warning("already authed.".into())),
                Cmd::Bye() => break,
                Cmd::Name(new_name) => {
                    BROADCAST_CHANNEL
                        .send(OutMsg::Name(new_name.clone(), nickname, uid))
                        .ok();
                    nickname = new_name;
                    None
                }
            },
            Err(err) => Some(OutMsg::Error(err.to_string())),
        };

        if let Some(response) = response {
            response.send(&out_tx).await.unwrap();
        }
    }

    OutMsg::GoodBye("See you later!".into())
        .send(&out_tx)
        .await
        .ok();

    BROADCAST_CHANNEL
        .send(OutMsg::Status(
            nickname.clone(),
            "disconnected".into(),
            uid_cell.load(Relaxed),
        ))
        .ok();
    println!("user {} ({nickname}) disconnected", uid_cell.load(Relaxed));

    if let Some(h) = sub_handle.take() {
        h.abort();
    }

    Ok(())
}
