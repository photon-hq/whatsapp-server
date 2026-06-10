package struct SendStickerCommand: Sendable, Equatable {

    package let recipient: String
    package let data: [UInt8]
    package let emojis: [String]
    package let accessibilityText: String?

    package init(
        recipient: String,
        data: [UInt8],
        emojis: [String] = [],
        accessibilityText: String? = nil
    ) {
        self.recipient = recipient
        self.data = data
        self.emojis = emojis
        self.accessibilityText = accessibilityText
    }

}
