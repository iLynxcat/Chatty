import ChattyProtocol
import Cocoa

class StatusViewController: NSViewController {

	var logView: NSTextView!

	override func loadView() {
		view = NSView()

		let scroller = NSScrollView()
		logView = NSTextView()
		logView.isEditable = false
		logView.drawsBackground = false
		scroller.documentView = logView
		scroller.hasVerticalScroller = true

		view.addSubview(scroller)

		scroller.translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			scroller.topAnchor.constraint(equalTo: view.topAnchor),
			scroller.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scroller.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			scroller.bottomAnchor.constraint(equalTo: view.bottomAnchor),
		])
	}

	func appendLog(_ message: ServerMessage, color: NSColor = .textColor) {
		let attrs: [NSAttributedString.Key: Any] = [
			.foregroundColor: color
		]
		let attributed = NSAttributedString(
			string: String(describing: message) + "\n", attributes: attrs)
		logView.textStorage?.append(attributed)
		logView.scrollToEndOfDocument(nil)
	}

}
