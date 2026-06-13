// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "Chatty",
	platforms: [
		.macOS(.v26)
	],
	targets: [
		.executableTarget(
			name: "Chatty",
			dependencies: [
				.target(name: "ChattyProtocol")
			],
			path: "mac",
			exclude: ["Info.plist"],
			resources: [.process("Resources")],
		),
		.target(
			name: "ChattyProtocol",
			path: "lib-swift",
		),
	],
	swiftLanguageModes: [.v6]
)
