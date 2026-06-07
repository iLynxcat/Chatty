import ChattyProtocol
import Cocoa
import Network

class ChattyClient: @unchecked Sendable {

	private var conn: NWConnection?
	private var lineBuffer = ""

	var onReceive: ((String) -> Void)?

	func connect(host: String, port: UInt16) {
		conn = NWConnection(
			host: NWEndpoint.Host(host),
			port: NWEndpoint.Port(rawValue: port)!,
			using: .tcp)

		conn?.stateUpdateHandler = { state in
			switch state {
			case .ready: self.receive()
			case .failed(let error):
				print("Failed: \(error)")

				if error.errorCode == 54 {
					print("Connection reset")
					exit(Int32(error.errorCode))
				}
			default: break
			}
		}
		conn?.start(queue: .global())
	}

	func send(_ text: String) {
		let data = Data((text + "\n").utf8)
		conn?.send(content: data, completion: .idempotent)
	}

	private func receive() {
		print("receiving...")
		conn?.receive(minimumIncompleteLength: 1, maximumLength: 65536) {
			[weak self]
			data, _, isComplete, error in

			guard let self else { return }

			if let data, let text = String(data: data, encoding: .utf8) {
				self.lineBuffer += text

				while let newline = self.lineBuffer.range(of: "\n") {
					let line = String(self.lineBuffer[..<newline.upperBound])
					lineBuffer = String(self.lineBuffer[newline.upperBound...])
					guard !line.isEmpty else { continue }
					DispatchQueue.main.async { self.onReceive?(line) }
				}
			}
			if !isComplete { self.receive() }

		}
	}

	func disconnect() {
		conn?.cancel()
		conn = nil
	}

}

struct OnlineUser {
	let name: String
	let uid: UInt32
}

extension ServerMessage {
	init?(parsedFromLine line: String) {
		let parser = ServerMessageParser(line)

		guard
			let verb = parser.getVerb()
		else { return nil }

		switch verb {
		case "CONNECTED":
			guard
				let name = parser.getNextParameter(named: "as"),
				let uidString = parser.getNextParameter(named: "uid"),
				parser.scanEnd()
			else { return nil }
			self = .connected(name: name, uid: UInt32(uidString)!)
		case "PING":
			guard
				let channel = parser.getNextParameter(named: "in"),
				parser.scanEnd()
			else { return nil }
			self = .ping(channel: channel)
		case "MSG":
			guard
				let channel = parser.getNextParameter(named: "in"),
				let author = parser.getNextParameter(named: "from"),
				let uidString = parser.getNextParameter(named: "uid"),
				let content = parser.getNextParameterUnnamed(greedy: true),
				parser.scanEnd()
			else { return nil }
			self = .message(channel: channel, name: author, uid: UInt32(uidString)!, body: content)
		case "NAME":
			guard
				let newName = parser.getNextParameterUnnamed(),
				let oldName = parser.getNextParameter(named: "was"),
				let uidString = parser.getNextParameter(named: "uid")
			else { return nil }
			self = .name(newName, oldName: oldName, uid: UInt32(uidString)!)
		case "WELCOME!":
			guard
				let message = parser.getNextParameterPlain(greedy: true),
				parser.scanEnd()
			else { return nil }
			self = .welcome(message)
		case "HINT!":
			guard
				let message = parser.getNextParameterPlain(greedy: true),
				parser.scanEnd()
			else { return nil }
			self = .hint(message)
		case "WARNING!":
			guard
				let message = parser.getNextParameterPlain(greedy: true),
				parser.scanEnd()
			else { return nil }
			self = .warning(message)
		case "ERROR!":
			guard
				let message = parser.getNextParameterPlain(greedy: true),
				parser.scanEnd()
			else { return nil }
			self = .error(message)
		case "BYE!":
			let message = parser.getNextParameterPlain(greedy: true)
			guard parser.scanEnd() else { return nil }
			self = .goodbye(message ?? "")
		case "STATUS":
			guard
				let name = parser.getNextParameterUnnamed(),
				let status = parser.getNextParameter(named: "status"),
				let uidString = parser.getNextParameter(named: "uid"),
				parser.scanEnd()
			else { return nil }
			self = .status(name, status: status, uid: UInt32(uidString)!)
		default:
			return nil
		}
	}
}
