import Foundation

public struct ServerMessageParser {

	let scanner: Scanner

	public init(_ content: String) {
		scanner = Scanner(string: content)
		scanner.caseSensitive = true
		scanner.charactersToBeSkipped = nil
	}

	public func getVerb() -> String? {
		guard
			let verb = scanner.scanUpToCharacters(from: .whitespacesAndNewlines),
			eatWhitespace()
		else { return nil }

		return verb
	}

	/// Scan for named parameters
	///
	/// i.e.
	/// 	VERB parameter:value
	/// 	VERB! code:value this is a greedy message
	public func getNextParameter(named name: String) -> String? {
		guard
			scanner.scanString("\(name):") != nil,
			let value = scanner.scanUpToCharacters(from: .whitespacesAndNewlines)
		else { return nil }
		_ = eatWhitespace()

		return value
	}

	/// Scan for unnamed parameters (prefixed)
	///
	/// i.e.
	/// 	VERB _:value
	/// 	VERB :this is a greedy value
	public func getNextParameterUnnamed(greedy: Bool = false) -> String? {
		let prefix = if greedy { ":" } else { "_:" }

		guard
			scanner.scanString(prefix) != nil,
			let value = getNextParameterPlain(greedy: greedy)
		else { return nil }
		_ = eatWhitespace()

		return value
	}

	/// Scan for plain parameters (non-prefixed)
	///
	/// i.e.
	/// 	VERB value_here
	/// 	VERB! this is a greedy value
	public func getNextParameterPlain(greedy: Bool = false) -> String? {
		let value =
			if greedy {
				scanner.scanUpToCharacters(from: .newlines)
			} else {
				scanner.scanUpToCharacters(from: .whitespacesAndNewlines)
			}

		return value

	}

	public func scanEnd() -> Bool {
		scanner.isAtEnd || scanner.scanCharacter()?.isNewline ?? false
	}

	private func eatWhitespace() -> Bool {
		scanner.scanCharacters(from: .whitespaces) != nil
	}

}

extension ServerMessage {
	public init?(parsedFromLine line: String) {
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
