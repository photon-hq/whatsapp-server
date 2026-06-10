package struct EditMessageCommand: Sendable, Equatable {

    package let messageId: String
    package let text: String

    package init(
        messageId: String,
        text: String
    ) {
        self.messageId = messageId
        self.text = text
    }

}
