import ChattyProtocol
import Cocoa

class ChatLogViewController: NSViewController {

	var onCommand: ((String) -> Void)?

	var model: ChatWindowViewModel!

	var logView: NSTextView!
	var input: NSTextField!

	override func loadView() {
		view = NSView()

		let scroller = NSScrollView()
		logView = NSTextView()
		logView.isEditable = false
		logView.drawsBackground = false
		scroller.documentView = logView
		scroller.hasVerticalScroller = true

		input = NSTextField()
		input.font = NSFont.systemFont(ofSize: 14)
		input.placeholderString = "say something..."
		input.delegate = self

		view.addSubview(scroller)
		view.addSubview(input)

		scroller.translatesAutoresizingMaskIntoConstraints = false
		input.translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			scroller.topAnchor.constraint(equalTo: view.topAnchor),
			scroller.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scroller.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			scroller.bottomAnchor.constraint(equalTo: input.topAnchor, constant: -4),

			input.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: +4),
			input.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
			input.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
		])
	}

	func appendLog(_ message: ServerMessage) {
		switch message {
		case .welcome(let message):
			appendLog(
				RichString(
					string: "\(message)\n",
					attributes: .systemStatus))
		case .connected(let name, let uid):
			appendLog(
				RichString(
					string: "Connected as ",
					attributes: .systemStatus))
			appendLog(
				RichString(
					string: name,
					attributes: .nameSelf))
			appendLog(
				RichString(
					string: " (#\(uid))\n",
					attributes: .systemStatus))
		case .message(channel: _, let name, let uid, let body):
			// TODO: ensure channel is current channel
			// TODO: color differently if "me"
			appendLog(
				RichString(
					string: "\(name):",
					attributes:
						model.isSelf(uid: uid)
						? .nameSelf
						: .nameOther))
			appendLog(
				RichString(string: " \(body)\n", attributes: .content))
		case .error(let message):
			appendLog(
				RichString(string: "\(message)\n", attributes: .error))
		case .warning(let message):
			appendLog(
				RichString(string: "\(message)\n", attributes: .warning))
		case .hint(let message),
			.goodbye(let message):
			appendLog(
				RichString(string: "\(message)\n", attributes: .systemStatus))
		case .name(let name, let oldName, let uid):
			appendLog(
				RichString(
					string: "\(oldName) (#\(uid)) is now ",
					attributes: .systemStatus))
			appendLog(
				RichString(
					string: "\(name)\n",
					attributes: .nameOther))
		case .ping(let channel):
			appendLog(
				RichString(
					string: "You are in #\(channel)\n",
					attributes: .systemStatus))
		case .status(let name, let status, let uid):
			appendLog(
				RichString(
					string: name,
					attributes:
						model.isSelf(uid: uid)
						? .nameSelf
						: .nameOther))
			appendLog(
				RichString(
					string: " is now \(status)\n",
					attributes: .systemStatus))
		}
		logView.scrollToEndOfDocument(nil)
	}

	private func appendLog(_ message: RichString) {
		logView.textStorage?.append(message)
	}

}

private typealias RichString = NSAttributedString

private typealias TextStyleSet = [NSAttributedString.Key: Any]
extension [NSAttributedString.Key: Any] {
	nonisolated(unsafe) static let nameSelf: Self =
		[
			.foregroundColor: NSColor.systemRed,
			.font: NSFont.boldSystemFont(ofSize: 14),
		]

	nonisolated(unsafe) static let nameOther: Self =
		[
			.foregroundColor: NSColor.systemBlue,
			.font: NSFont.boldSystemFont(ofSize: 14),
		]

	nonisolated(unsafe) static let systemStatus: Self =
		[
			.foregroundColor: NSColor.secondaryLabelColor,
			.font: NSFont.systemFont(ofSize: 14),
		]

	nonisolated(unsafe) static let warning: Self =
		[
			.foregroundColor: NSColor.systemOrange,
			.font: NSFont.systemFont(ofSize: 14),
		]

	nonisolated(unsafe) static let error: Self =
		[
			.foregroundColor: NSColor.systemRed,
			.font: NSFont.systemFont(ofSize: 14),
		]

	nonisolated(unsafe) static let content: Self =
		[
			.foregroundColor: NSColor.labelColor,
			.font: NSFont.systemFont(ofSize: 14),
		]

}

extension ChatLogViewController: NSTextFieldDelegate {
	func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool
	{
		if selector == #selector(insertNewline(_:)) {
			let command = input.stringValue

			input.stringValue = ""

			onCommand?(command)

			return true
		}
		return false
	}
}
