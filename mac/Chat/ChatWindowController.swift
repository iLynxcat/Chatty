import Cocoa
import Combine

class ChatWindowController: NSWindowController, NSWindowDelegate {

	let client: ChattyClient

	var model: ChatWindowViewModel!
	private var cancellables = Set<AnyCancellable>()

	var log: ChatLogViewController!

	init(client: ChattyClient) {
		self.client = client

		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
			styleMask: [.closable, .resizable, .titled],
			backing: .buffered,
			defer: false)
		super.init(window: window)

		setupContent()

		if !window.setFrameUsingName("Chat") {
			window.center()
		}
		window.setFrameAutosaveName("Chat")

		log.onCommand = { [weak self] command in
			self?.client.send(command)
		}
		log.input.becomeFirstResponder()

	}

	required init(coder: NSCoder) { fatalError() }

	private func setupContent() {
		guard
			let window,
			let contentView = window.contentView
		else { return }

		self.model = ChatWindowViewModel(user: nil, in: nil)
		self.log = ChatLogViewController()
		self.log.model = model

		model.$windowTitle.receive(on: RunLoop.main)
			.sink { [weak self] _ in
				self?.window?.title = self?.model.windowTitle ?? ""
			}
			.store(in: &cancellables)

		window.title = model.windowTitle
		window.delegate = self

		contentView.addSubview(log.view)

		log.view.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			log.view.topAnchor.constraint(equalTo: contentView.topAnchor),
			log.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			log.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			log.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
		])

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
