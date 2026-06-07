import Cocoa

class ConsoleViewController: NSViewController {

	var onCommand: ((String) -> Void)?

	var textView: NSTextView!
	var input: NSTextField!

	override func loadView() {
		view = NSView()

		let scroller = NSScrollView()
		textView = NSTextView()
		textView.isEditable = false
		textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
		textView.backgroundColor = .black
		textView.textColor = .orange
		textView.drawsBackground = true
		scroller.documentView = textView
		scroller.hasVerticalScroller = true

		input = NSTextField()
		input.font = NSFont.systemFont(ofSize: 14)
		input.placeholderString = "command"
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

	func appendOutput(_ text: String, color: NSColor = .lightGray) {
		let attrs: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
			.foregroundColor: color,
		]
		let text = if !text.hasSuffix("\n") { "\(text)\n" } else { text }
		let attributed = NSAttributedString(string: text, attributes: attrs)
		textView.textStorage?.append(attributed)
		textView.scrollToEndOfDocument(nil)
	}
}

extension ConsoleViewController: NSTextFieldDelegate {
	func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool
	{
		if selector == #selector(insertNewline(_:)) {
			let command = input.stringValue

			appendOutput("> \(command)", color: .systemCyan)
			input.stringValue = ""

			onCommand?(command)

			return true
		}
		return false
	}
}
