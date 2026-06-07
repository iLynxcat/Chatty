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
