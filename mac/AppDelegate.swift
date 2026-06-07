import ChattyProtocol
import Cocoa

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

	static func main() {
		let app = NSApplication.shared
		let delegate = AppDelegate()
		app.delegate = delegate
		app.run()
	}

	let client = ChattyClient()

	var inspector: InspectorWindowController!
	var chatWindow: ChatWindowController!

	private var inspectorItem: NSMenuItem!
	private var chatWindowItem: NSMenuItem!

	func applicationDidFinishLaunching(_ notification: Notification) {
		NSApp.setActivationPolicy(.regular)
		NSApp.activate(ignoringOtherApps: true)

		chatWindow = ChatWindowController(client: client)
		inspector = InspectorWindowController(client: client)

		let menu = NSMenu()
		NSApp.mainMenu = menu

		let appMenu = NSMenu()
		menu.addItem(
			withTitle: "",
			action: nil,
			keyEquivalent: ""
		).submenu = appMenu
		appMenu.addItem(
			withTitle: "Quit",
			action: #selector(NSApplication.terminate(_:)),
			keyEquivalent: "q")

		let editMenu = NSMenu()
		menu.addItem(
			withTitle: "Edit",
			action: nil,
			keyEquivalent: ""
		).submenu = editMenu

		let windowsMenu = NSMenu()
		menu.addItem(
			withTitle: "Window",
			action: nil,
			keyEquivalent: ""
		).submenu = windowsMenu

		NSApp.windowsMenu = windowsMenu
		windowsMenu.addItem(.separator())
		inspectorItem = windowsMenu.addItem(
			withTitle: "Show Protocol Inspector",
			action: #selector(self.toggleInspector),
			keyEquivalent: "1")
		chatWindowItem = windowsMenu.addItem(
			withTitle: "Show Chat",
			action: #selector(self.toggleChat),
			keyEquivalent: "2")
		inspectorItem.state = inspector.menuItemState
		chatWindowItem.state = chatWindow.menuItemState
		windowsMenu.addItem(.separator())
		windowsMenu.addItem(
			withTitle: "Close Window",
			action: #selector(NSWindow.performClose(_:)),
			keyEquivalent: "w")

		client.onReceive = { [weak self] text in
			guard let self else { return }

			inspector?.consoleView.appendOutput(text)

			if let msg = ServerMessage(parsedFromLine: text) {
				inspector?.statusView.appendLog(msg)

				chatWindow?.log.appendLog(msg)
				chatWindow?.model.handleMessage(msg)
			} else {
				let alert = NSAlert()
				alert.messageText = "Server message failed to parse"
				alert.informativeText = "more detailed error parsing is not yet implemented, sorry"
				alert.alertStyle = .warning
				if let window = inspector?.window {
					alert.beginSheetModal(for: window)
				}
			}
		}

		client.connect(host: "localhost", port: 4307)

		chatWindow.showWindow(self)
		chatWindow.window?.makeKeyAndOrderFront(self)

		NSApp.activate()
		inspectorItem.state = inspector.menuItemState
	}

	@objc private func toggleChat() {
		if NSApp.keyWindow != chatWindow.window {
			chatWindow.window?.makeKeyAndOrderFront(self)
			return
		}

		chatWindow.toggle()
		chatWindowItem.state = chatWindow.menuItemState
	}

	@objc private func toggleInspector() {
		if NSApp.keyWindow != inspector.window {
			inspector.window?.makeKeyAndOrderFront(self)
			return
		}

		inspector.toggle()
		inspectorItem.state = inspector.menuItemState
	}

	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		if menuItem.action == #selector(self.toggleInspector) {
			menuItem.state = inspector.menuItemState
		}
		if menuItem.action == #selector(self.toggleChat) {
			menuItem.state = chatWindow.menuItemState
		}
		return true
	}

}
