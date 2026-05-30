package struct MessageText: Sendable, Equatable {

    package let messageId: String
    package let text: String
    package let replyToMessageId: String?

    package init(
        messageId: String,
        text: String,
        replyToMessageId: String? = nil
    ) {
        self.messageId = messageId
        self.text = text
        self.replyToMessageId = replyToMessageId
    }

}

package struct MessageAttachment: Sendable, Equatable {

    package let messageId: String
    package let kind: MessageAttachmentKind
    package let caption: String?
    package let localPath: String?
    package let fileSize: Int64?
    package let title: String?
    package let replyToMessageId: String?

    package init(
        messageId: String,
        kind: MessageAttachmentKind,
        caption: String? = nil,
        localPath: String? = nil,
        fileSize: Int64? = nil,
        title: String? = nil,
        replyToMessageId: String? = nil
    ) {
        self.messageId = messageId
        self.kind = kind
        self.caption = caption
        self.localPath = localPath
        self.fileSize = fileSize
        self.title = title
        self.replyToMessageId = replyToMessageId
    }

}

package struct MessageReaction: Sendable, Equatable {

    package let messageId: String
    package let emoji: String?
    package let actorJid: String?
    package let reactionId: String?

    package init(
        messageId: String,
        emoji: String?,
        actorJid: String? = nil,
        reactionId: String? = nil
    ) {
        self.messageId = messageId
        self.emoji = emoji
        self.actorJid = actorJid
        self.reactionId = reactionId
    }

}

package struct MessageReceiptUpdate: Sendable, Equatable {

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
