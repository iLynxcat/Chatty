import AppKit
import ChattyProtocol
import Combine

class ChatWindowViewModel: ObservableObject {

	@Published var user: OnlineUser? { didSet { updateTitle() } }
	@Published var channel: String? { didSet { updateTitle() } }

	@Published private(set) var windowTitle = "Not Logged In"

	init(user: OnlineUser?, in channel: String?) {
		self.user = user
		self.channel = channel
		updateTitle()
	}

	private func updateTitle() {
		windowTitle =
			if let user {
				"\(user.name) – \(channel != nil ? "#\(channel!)" : "no channel active")"
			} else {
				"Not Logged In"
			}
	}

	func handleMessage(_ message: ServerMessage) {
		switch message {
		case .connected(let name, let uid):
			guard
				self.user == nil
			else { break }

			print("user is now \(name)")
			if self.user == nil,
				let url = Bundle.module.url(
					forResource: "hello",
					withExtension: "mp3"),
				let sound = NSSound(
					contentsOf: url,
					byReference: false)
			{
				sound.play()
			}

			self.user = OnlineUser(name: name, uid: uid)
		case .name(let newName, _, let uid):
			guard let user, user.uid == uid else { break }
			print("user is renamed to \(newName)")
			self.user = OnlineUser(name: newName, uid: uid)
		case .ping(let channel):
			self.channel = channel
		case .message(_, _, let uid, _):
			if uid != self.user?.uid,
				let url = Bundle.module.url(forResource: "ping", withExtension: "mp3"),
				let sound = NSSound(contentsOf: url, byReference: false)

			{
				sound.play()
			}
		case .error(_), .warning(_):
			if let url = Bundle.module.url(
				forResource: "uhoh",
				withExtension: "mp3"),
				let sound = NSSound(
					contentsOf: url,
					byReference: false)
			{
				sound.play()
			}
		default: return
		}
	}

	func isSelf(name: String) -> Bool {
		user?.name == name
	}

	func isSelf(uid: UInt32) -> Bool {
		user?.uid == uid
	}

}
