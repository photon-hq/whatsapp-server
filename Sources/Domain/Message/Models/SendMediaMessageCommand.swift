package struct SendMediaMessageCommand: Sendable, Equatable {

    package let recipient: String
    package let type: MediaType
    package let data: [UInt8]
    package let caption: String?
    package let accessibilityText: String?

    package init(
        recipient: String,
        type: MediaType,
        data: [UInt8],
        caption: String? = nil,
        accessibilityText: String? = nil
    ) {
        self.recipient = recipient
        self.type = type
        self.data = data
        self.caption = caption
        self.accessibilityText = accessibilityText
    }

}
