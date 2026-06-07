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
