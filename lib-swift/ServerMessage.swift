public enum ServerMessage {

	case welcome(_ message: String)
	case hint(_ message: String)
	case warning(_ message: String)
	case error(_ message: String)

	case connected(name: String, uid: UInt32)
	case ping(channel: String)

	case message(channel: String, name: String, uid: UInt32, body: String)

	case name(_ name: String, oldName: String, uid: UInt32)
	case status(_ name: String, status: String, uid: UInt32)

	case goodbye(_ reason: String)

}
