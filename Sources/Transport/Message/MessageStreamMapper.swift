import Domain
import SwiftProtobuf

enum MessageStreamMapper {

    static func toProto(_ event: SequencedMessageChange) -> PWApp_MessageChangeEvent {
        var proto = PWApp_MessageChangeEvent()
        proto.recipient = event.change.recipient
        proto.occurredAt = Google_Protobuf_Timestamp(date: event.change.occurredAt)
        proto.isFromMe = event.change.isFromMe

        switch event.change.change {
        case .text(let text):
            proto.change = .text(toProto(text))

        case .attachment(let attachment):
            proto.change = .attachment(toProto(attachment))

        case .reaction(let reaction):
            proto.change = .reaction(toProto(reaction))

        case .receipt(let receipt):
            proto.change = .receipt(toProto(receipt))
        }

        return proto
    }

    static func toSubscribeProto(
        _ event: SequencedMessageChange
    ) -> PWApp_SubscribeMessageEventsResponse {
        var response = PWApp_SubscribeMessageEventsResponse()
        response.sequence = event.sequence
        response.payload = .messageChanged(toProto(event))

        return response
    }

    private static func toProto(_ text: MessageText) -> PWApp_MessageText {
        var proto = PWApp_MessageText()
        proto.messageID = text.messageId
        proto.text = text.text
        if let replyToMessageId = text.replyToMessageId {
            proto.replyToMessageID = replyToMessageId
        }

        return proto
    }

    private static func toProto(_ attachment: MessageAttachment) -> PWApp_MessageAttachment {
        var proto = PWApp_MessageAttachment()
        proto.messageID = attachment.messageId
        proto.kind = MessageMapper.toProto(attachment.kind)

        if let caption = attachment.caption {
            proto.caption = caption
        }

        if let localPath = attachment.localPath {
            proto.localPath = localPath
        }

        if let fileSize = attachment.fileSize {
            proto.fileSize = fileSize
        }

        if let title = attachment.title {
            proto.title = title
        }

        if let replyToMessageId = attachment.replyToMessageId {
            proto.replyToMessageID = replyToMessageId
        }

        return proto
    }

    private static func toProto(_ reaction: MessageReaction) -> PWApp_MessageReaction {
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

    private static func toProto(_ receipt: MessageReceiptUpdate) -> PWApp_MessageReceiptUpdate {
        var proto = PWApp_MessageReceiptUpdate()
        proto.messageID = receipt.messageId
        proto.receiptDigest = receipt.receiptDigest

        return proto
    }

}
