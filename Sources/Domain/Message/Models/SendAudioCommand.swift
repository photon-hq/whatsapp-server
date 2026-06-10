package struct SendAudioCommand: Sendable, Equatable {

    package let recipient: String
    package let data: [UInt8]
    package let mimeType: String?

    package init(
        recipient: String,
        data: [UInt8],
        mimeType: String? = nil
    ) {
        self.recipient = recipient
        self.data = data
        self.mimeType = mimeType
    }

}
