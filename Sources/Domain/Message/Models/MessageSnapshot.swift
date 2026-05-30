import Foundation

package struct MessageSnapshot: Sendable, Equatable {

    package let messageId: String
    package let recipient: String
    package let chatJid: String
    package let partnerName: String?
    package let stanzaId: String
    package let isFromMe: Bool
    package let messageType: Int
    package let messageStatus: Int?
    package let messageErrorStatus: Int?
    package let text: String
    package let messageDate: Date?
    package let sentDate: Date?
    package let fromJid: String?
    package let toJid: String?
    package let pushName: String?
    package let replyToMessageId: String?
    package let media: MessageMediaSnapshot?
    package let latestReaction: MessageReactionSnapshot?
    package let receiptDigest: String?

    package init(
        messageId: String,
        recipient: String,
        chatJid: String = "",
        partnerName: String? = nil,
        stanzaId: String = "",
        isFromMe: Bool,
        messageType: Int = 0,
        messageStatus: Int? = nil,
        messageErrorStatus: Int? = nil,
        text: String = "",
        messageDate: Date? = nil,
        sentDate: Date? = nil,
        fromJid: String? = nil,
        toJid: String? = nil,
        pushName: String? = nil,
        replyToMessageId: String? = nil,
        media: MessageMediaSnapshot? = nil,
        latestReaction: MessageReactionSnapshot? = nil,
        receiptDigest: String? = nil
    ) {
        self.messageId = messageId
        self.recipient = recipient
        self.chatJid = chatJid
        self.partnerName = partnerName
        self.stanzaId = stanzaId
        self.isFromMe = isFromMe
        self.messageType = messageType
        self.messageStatus = messageStatus
        self.messageErrorStatus = messageErrorStatus
        self.text = text
        self.messageDate = messageDate
        self.sentDate = sentDate
        self.fromJid = fromJid
        self.toJid = toJid
        self.pushName = pushName
        self.replyToMessageId = replyToMessageId
        self.media = media
        self.latestReaction = latestReaction
        self.receiptDigest = receiptDigest
    }

}

package struct MessageMediaSnapshot: Sendable, Equatable {

    package let kind: MessageAttachmentKind
    package let title: String?
    package let localPath: String?
    package let mediaUrl: String?
    package let fileSize: Int64?
    package let vcardName: String?
    package let vcardString: String?
    package let latitude: Double?
    package let longitude: Double?
    package let thumbnailLocalPath: String?
    package let xmppThumbnailPath: String?
    package let mediaUrlDate: Date?
    package let cloudStatus: Int?

    package init(
        kind: MessageAttachmentKind,
        title: String? = nil,
        localPath: String? = nil,
        mediaUrl: String? = nil,
        fileSize: Int64? = nil,
        vcardName: String? = nil,
        vcardString: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        thumbnailLocalPath: String? = nil,
        xmppThumbnailPath: String? = nil,
        mediaUrlDate: Date? = nil,
        cloudStatus: Int? = nil
    ) {
        self.kind = kind
        self.title = title
        self.localPath = localPath
        self.mediaUrl = mediaUrl
        self.fileSize = fileSize
        self.vcardName = vcardName
        self.vcardString = vcardString
        self.latitude = latitude
        self.longitude = longitude
        self.thumbnailLocalPath = thumbnailLocalPath
        self.xmppThumbnailPath = xmppThumbnailPath
        self.mediaUrlDate = mediaUrlDate
        self.cloudStatus = cloudStatus
    }

}

package struct MessageReactionSnapshot: Sendable, Equatable {

    package let messageId: String
    package let emoji: String?
    package let actorJid: String?
    package let reactionId: String?

    package init(
        messageId: String,
        emoji: String? = nil,
        actorJid: String? = nil,
        reactionId: String? = nil
    ) {
        self.messageId = messageId
        self.emoji = emoji
        self.actorJid = actorJid
        self.reactionId = reactionId
    }

}
