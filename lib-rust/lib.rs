use crate::error::CmdParseError;

use std::fmt::{self};

pub type UserId = u32;

#[derive(Clone)]
pub enum OutMsg {
    /// Send welcome message for user.
    /// (_:message)
    Welcome(String),
    /// Send user a hint.
    /// (_:message)
    Hint(String),
    /// Send user a warning.
    /// (_:message)
    Warning(String),
    /// Notify user of an error.
    /// (_:message)
    Error(String),

    /// Acknowledge successful connection attempt.
    /// (as:name uid:)
    Connected(String, UserId),
    /// Ping client.
    /// (in:channel)
    Ping(String),

    /// Deliver chat message to user.
    /// (in:channel from:name uid: _:body)
    Message(String, String, UserId, String),

    /// A user's name was updated.
    /// (_:name was:name uid:)
    Name(String, String, UserId),
    /// A user's status has changed.
    /// (_:name status: uid:)
    Status(String, String, UserId),

    /// Connection is ending.
    /// (_:reason)
    GoodBye(String),
}

impl OutMsg {
    pub fn to_message(&self) -> String {
        match self {
            OutMsg::Welcome(message) => format!("WELCOME! {message}"),
            OutMsg::Hint(message) => format!("HINT! {message}"),
            OutMsg::Warning(message) => format!("WARNING! {message}"),
            OutMsg::Error(message) => format!("ERROR! {message}"),

            OutMsg::Connected(username, uid) => format!("CONNECTED as:{username} uid:{uid}"),
            OutMsg::Ping(channel) => format!("PING in:{channel}"),

            OutMsg::Message(channel, author, uid, body) => {
                format!("MSG in:{channel} from:{author} uid:{uid} :{body}")
            }

            OutMsg::Name(name, was, uid) => format!("NAME _:{name} was:{was} uid:{uid}"),
            OutMsg::Status(name, status, uid) => {
                format!("STATUS _:{name} status:{status} uid:{uid}")
            }

            OutMsg::GoodBye(msg) => format!("BYE! {msg}"),
        }
    }
}

pub enum Cmd {
    /// Login request. (i.e. "/LOGIN jenkins" -> Login("jenkins"))
    /// (_:name)
    Login(String),

    /// Sending a message.
    /// (to:channel :body)
    Send(String, String),

    /// Switch to a different channel.
    /// (to:channel)
    Switch(String),

    /// Identify the authenticated user.
    /// ()
    Identify(),
    /// Set name.
    /// (_:name)
    Name(String),

    /// Disconnect from the server.
    /// ()
    Bye(),
}

impl fmt::Display for Cmd {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Cmd::Login(name) => write!(f, "/LOGIN {name}"),
            Cmd::Send(channel, body) => write!(f, "/SEND to:{channel} :{body}"),
            Cmd::Switch(channel) => write!(f, "/SWITCH to:{channel}"),
            Cmd::Identify() => write!(f, "/IDENTIFY"),
            Cmd::Name(new_name) => write!(f, "/NAME {new_name}"),
            Cmd::Bye() => write!(f, "/BYE"),
        }
    }
}

impl TryFrom<&str> for Cmd {
    type Error = CmdParseError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        if value.len() > 256 {
            return Err(CmdParseError::InputOverflow);
        }

        let mut parts = value.trim().splitn(2, char::is_whitespace);
        let verb = parts.next().unwrap_or("");
        let args = parts.next().unwrap_or("");

        match verb {
            "/LOGIN" => {
                let (name, _) = args
                    .split_once(|c: char| !c.is_ascii_alphanumeric())
                    .unwrap_or((args, ""));

                if name.is_empty() || name.len() < 2 || name.len() > 16 {
                    return Err(CmdParseError::InvalidArgument("_:<<name (2-16 chars)>>"));
                }

                Ok(Cmd::Login(name.to_string()))
            }
            "/SEND" => {
                let (channel, body) = args
                    .split_once(' ')
                    .ok_or(CmdParseError::MissingArgument("to:channel _:body"))?;

                let channel = channel
                    .strip_prefix("to:")
                    .ok_or(CmdParseError::MissingArgument("<to:channel>"))?;

                if channel.is_empty() {
                    return Err(CmdParseError::InvalidArgument("to:<<channel>>"));
                }

                let body = body
                    .strip_prefix(":")
                    .ok_or(CmdParseError::MissingArgument("to:<_:body>"))?;

                if body.is_empty() {
                    return Err(CmdParseError::InvalidArgument("to:_:<<body>>"));
                }

                Ok(Cmd::Send(channel.to_string(), body.to_string()))
            }
            "/SWITCH" => {
                let (channel, _) = args.split_once(' ').unwrap_or((args, ""));

                let channel = channel
                    .strip_prefix("to:")
                    .ok_or(CmdParseError::MissingArgument("<to:channel>"))?;

                if channel.is_empty() {
                    return Err(CmdParseError::InvalidArgument("to:<<channel>>"));
                }

                Ok(Cmd::Switch(channel.to_string()))
            }
            "/NAME" => {
                let (name, _) = args
                    .split_once(|c: char| !c.is_ascii_alphanumeric())
                    .unwrap_or((args, ""));

                if name.is_empty() || name.len() < 2 || name.len() > 16 {
                    return Err(CmdParseError::InvalidArgument("_:<<name (2-16 chars)>>"));
                }

                Ok(Cmd::Name(name.into()))
            }
            "/IDENTIFY" => Ok(Cmd::Identify()),
            "/BYE" => Ok(Cmd::Bye()),
            _ if verb.starts_with('/') => Err(CmdParseError::UnknownCommand),
            _ => Ok(Cmd::Send("{current}".to_string(), value.to_string())),
        }
    }
}

pub mod error {
    use std::fmt;

    pub enum CmdParseError {
        UnknownCommand,
        InputOverflow,
        MissingArgument(&'static str),
        InvalidArgument(&'static str),
    }

    impl fmt::Display for CmdParseError {
        fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            match self {
                Self::UnknownCommand => write!(f, "unknown command"),
                Self::InputOverflow => write!(f, "input too long"),
                Self::MissingArgument(arg) => write!(f, "missing argument: {}", arg),
                Self::InvalidArgument(arg) => write!(f, "invalid argument: {}", arg),
            }
        }
    }
}
