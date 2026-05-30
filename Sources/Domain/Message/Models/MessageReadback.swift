import Foundation

package struct SentTextReadbackQuery: Sendable, Equatable {

    package let messageId: String
    package let recipient: String
    package let text: String
    package let replyToMessageId: String?

    package init(
        messageId: String,
        recipient: String,
        text: String,
        replyToMessageId: String? = nil
    ) {
        self.messageId = messageId
        self.recipient = recipient
        self.text = text
        self.replyToMessageId = replyToMessageId
    }

}

package struct SentMediaReadbackQuery: Sendable, Equatable {

    package let recipient: String
    package let type: MediaType
    package let caption: String?
    package let notBefore: Date

    package init(
        recipient: String,
        type: MediaType,
        caption: String? = nil,
        notBefore: Date
    ) {
        self.recipient = recipient
        self.type = type
        self.caption = caption
        self.notBefore = notBefore
    }

}

package struct ReactionReadbackQuery: Sendable, Equatable {

    package let messageId: String
    package let emoji: String
    package let previousReceiptDigest: String?

    package init(
        messageId: String,
        emoji: String,
        previousReceiptDigest: String? = nil
    ) {
        self.messageId = messageId
        self.emoji = emoji
        self.previousReceiptDigest = previousReceiptDigest
    }

}

package struct MessageReceiptReadback: Sendable, Equatable {

    package let messageId: String
    package let receiptDigest: String

    package init(
        messageId: String,
        receiptDigest: String
    ) {
        self.messageId = messageId
        self.receiptDigest = receiptDigest
    }

}

package struct MessageReactionReadback: Sendable, Equatable {

    package let receipt: MessageReceiptReadback
    package let reaction: MessageReactionSnapshot

    package init(
        receipt: MessageReceiptReadback,
        reaction: MessageReactionSnapshot
    ) {
        self.receipt = receipt
        self.reaction = reaction
    }

}
