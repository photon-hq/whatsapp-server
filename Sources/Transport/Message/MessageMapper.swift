import Domain
import SwiftProtobuf

enum MessageMapper {

    static func toDomain(_ proto: PWApp_TextBlock, index: Int) throws -> TextBlock {
        try toDomain(proto, field: "content[\(index)]")
    }

    private static func toDomain(_ proto: PWApp_TextBlock, field: String) throws -> TextBlock {
        TextBlock(
            type: try toDomain(proto.type, field: "\(field).type"),
            text: try proto.text.enumerated().map { runIndex, run in
                try toDomain(run, field: "\(field).text[\(runIndex)]")
            }
        )
    }

    private static func toDomain(_ proto: PWApp_TextRun, field: String) throws -> TextRun {
        TextRun(
            text: proto.text,
            styles: try proto.styles.enumerated().map { styleIndex, style in
                try toDomain(style, field: "\(field).styles[\(styleIndex)]")
            }
        )
    }

    private static func toDomain(
        _ proto: PWApp_TextBlockType,
        field: String
    ) throws -> TextBlockType {
        switch proto {
        case .normal:
            .normal

        case .quote:
            .quote

        case .bullet:
            .bullet

        case .numbered:
            .numbered

        case .UNRECOGNIZED:
            throw DomainError(.invalidArgument, "Unknown text block type")
                .with("field", field)
        }
    }

    private static func toDomain(_ proto: PWApp_TextStyle, field: String) throws -> TextStyle {
        switch proto {
        case .bold:
            .bold
        case .italic:
            .italic

        case .strikethrough:
            .strikethrough

        case .code:
            .code

        case .unspecified, .UNRECOGNIZED:
            throw DomainError(.invalidArgument, "Unknown text style")
                .with("field", field)
        }
    }

    static func toDomain(_ proto: PWApp_MediaKind) throws -> MediaType {
        switch proto {
        case .image:
            .image

        case .video:
            .video

        case .unspecified, .UNRECOGNIZED:
            throw DomainError(.invalidArgument, "Unknown media kind")
                .with("field", "media.kind")
        }
    }

    static func toMessageResponse(_ message: MessageSnapshot) -> PWApp_MessageResponse {
        var response = PWApp_MessageResponse()
        response.message = toProto(message)
        return response
    }

    static func toListMessagesResponse(_ page: MessagePage) -> PWApp_ListMessagesResponse {
        var response = PWApp_ListMessagesResponse()
        response.messages = page.messages.map(toProto)
        if let nextPageToken = page.nextPageToken {
            response.nextPageToken = nextPageToken
        }

        return response
    }

    static func toProto(_ message: MessageSnapshot) -> PWApp_Message {
        var proto = PWApp_Message()
        proto.messageID = message.messageId
        proto.recipient = message.recipient
        proto.chatJid = message.chatJid
        if let partnerName = message.partnerName {
            proto.partnerName = partnerName
        }
        proto.stanzaID = message.stanzaId
        proto.isFromMe = message.isFromMe
        proto.messageType = Int32(message.messageType)
        if let messageStatus = message.messageStatus {
            proto.messageStatus = Int32(messageStatus)
        }
        if let messageErrorStatus = message.messageErrorStatus {
            proto.messageErrorStatus = Int32(messageErrorStatus)
        }
        if let messageDate = message.messageDate {
            proto.messageDate = Google_Protobuf_Timestamp(date: messageDate)
        }
        if let sentDate = message.sentDate {
            proto.sentDate = Google_Protobuf_Timestamp(date: sentDate)
        }
        proto.text = message.text
        if let fromJid = message.fromJid {
            proto.fromJid = fromJid
        }
        if let toJid = message.toJid {
            proto.toJid = toJid
        }
        if let pushName = message.pushName {
            proto.pushName = pushName
        }
        if let replyToMessageId = message.replyToMessageId {
            proto.replyToMessageID = replyToMessageId
        }
        if let media = message.media {
            proto.media = toProto(media)
        }
        if let latestReaction = message.latestReaction {
            proto.latestReaction = toProto(latestReaction)
        }
        if let receiptDigest = message.receiptDigest {
            proto.receiptDigest = receiptDigest
        }

        return proto
    }

    private static func toProto(_ media: MessageMediaSnapshot) -> PWApp_MessageMedia {
        var proto = PWApp_MessageMedia()
        proto.kind = toProto(media.kind)
        if let title = media.title {
            proto.title = title
        }
        if let localPath = media.localPath {
            proto.localPath = localPath
        }
        if let mediaUrl = media.mediaUrl {
            proto.mediaURL = mediaUrl
        }
        if let fileSize = media.fileSize {
            proto.fileSize = fileSize
        }
        if let vcardName = media.vcardName {
            proto.vcardName = vcardName
        }
        if let vcardString = media.vcardString {
            proto.vcardString = vcardString
        }
        if let latitude = media.latitude {
            proto.latitude = latitude
        }
        if let longitude = media.longitude {
            proto.longitude = longitude
        }
        if let thumbnailLocalPath = media.thumbnailLocalPath {
            proto.thumbnailLocalPath = thumbnailLocalPath
        }
        if let xmppThumbnailPath = media.xmppThumbnailPath {
            proto.xmppThumbnailPath = xmppThumbnailPath
        }
        if let mediaUrlDate = media.mediaUrlDate {
            proto.mediaURLDate = Google_Protobuf_Timestamp(date: mediaUrlDate)
        }
        if let cloudStatus = media.cloudStatus {
            proto.cloudStatus = Int32(cloudStatus)
        }

        return proto
    }

    private static func toProto(_ reaction: MessageReactionSnapshot) -> PWApp_MessageReaction {
        var proto = PWApp_MessageReaction()
        proto.messageID = reaction.messageId

        if let emoji = reaction.emoji {
            proto.emoji = emoji
        }

        if let actorJid = reaction.actorJid {
            proto.actorJid = actorJid
        }

        if let reactionId = reaction.reactionId {
            proto.reactionID = reactionId
        }

        return proto
    }

    static func toProto(_ kind: MessageAttachmentKind) -> PWApp_MessageAttachmentKind {
        switch kind {
        case .image:
            .image
        case .video:
            .video
        case .audio:
            .audio
        case .voice:
            .voice
        case .document:
            .document
        case .sticker:
            .sticker
        case .contact:
            .contact
        case .location:
            .location
        }
    }

}
