import Cocoa

class InspectorWindowController: NSWindowController, NSWindowDelegate {

	let client: ChattyClient

	var statusView: StatusViewController!
	var consoleView: ConsoleViewController!

	init(client: ChattyClient) {
		self.client = client

		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
			styleMask: [.closable, .resizable, .titled],
			backing: .buffered,
			defer: false)
		window.title = "Protocol Inspector"
		super.init(window: window)

		window.delegate = self

		setupContent()
		setupClient()

		if !window.setFrameUsingName("ProtocolInspector") {
			window.center()
		}
		window.setFrameAutosaveName("ProtocolInspector")
		consoleView.input.becomeFirstResponder()
	}

	required init?(coder: NSCoder) { fatalError() }

	private func setupContent() {
		guard let window else { return }

		let splitView = NSSplitViewController()

		statusView = StatusViewController()
		consoleView = ConsoleViewController()

		let leftPane = NSSplitViewItem(viewController: statusView)
		leftPane.minimumThickness = 240

		let rightPane = NSSplitViewItem(viewController: consoleView)
		rightPane.minimumThickness = 240

		splitView.addSplitViewItem(leftPane)
		splitView.addSplitViewItem(rightPane)

		window.contentViewController = splitView
		window.setContentSize(NSSize(width: 480, height: 320))

	}

	private func setupClient() {
		consoleView.onCommand = { [weak self] command in
			self?.client.send(command)
		}
	}

	@objc func toggle() {
		if window?.isVisible == true {
			close()
		} else {
			showWindow(self)
		}
	}

	var menuItemState: NSControl.StateValue {
		window?.isVisible == true ? .on : .off
	}

}
