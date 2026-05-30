package struct SendReactionCommand: Sendable, Equatable {

    package let messageId: String
    package let emoji: String

    package init(
        messageId: String,
        emoji: String
    ) {
        self.messageId = messageId
        self.emoji = emoji
    }

}
