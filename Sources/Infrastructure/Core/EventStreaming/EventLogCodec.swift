import Domain
import Foundation

enum EventLogCodec {

    private static let payloadVersion = 1

    static func encode(_ event: DomainEvent) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970

        return try encoder.encode(
            StoredPayloadDTO(
                version: payloadVersion,
                event: DomainEventDTO(event)
            )
        )
    }

    static func decode(_ data: Data) throws -> DomainEvent {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        let stored = try decoder.decode(StoredPayloadDTO.self, from: data)

        guard stored.version == payloadVersion else {
            throw DomainError(.internalError, "Unsupported persisted event version")
                .with("version", "\(stored.version)")
                .with("supported_version", "\(payloadVersion)")
        }

        return try stored.event.domain
    }

}


private struct StoredPayloadDTO: Codable {

    let version: Int
    let event: DomainEventDTO

}


private struct DomainEventDTO: Codable {

    var message: MessageDomainEventDTO?
    var poll: PollDomainEventDTO?

    init(_ domain: DomainEvent) {
        switch domain {
        case .message(let event):
            message = MessageDomainEventDTO(event)

        case .poll(let event):
            poll = PollDomainEventDTO(event)
        }
    }

    var domain: DomainEvent {
        get throws {
            let present = [
                message.map { _ in "message" },
                poll.map { _ in "poll" },
            ].compactMap { $0 }

            guard present.count == 1 else {
                throw DomainError(.internalError, "Domain event payload must contain exactly one domain")
            }

            if let message {
                return .message(try message.domain)
            }

            if let poll {
                return .poll(try poll.domain)
            }

            throw DomainError(.internalError, "Domain event payload is empty")
        }
    }

}


private struct MessageDomainEventDTO: Codable {

    var changed: MessageChangeEventDTO?

    init(_ domain: MessageDomainEvent) {
        switch domain {
        case .changed(let event):
            changed = MessageChangeEventDTO(event)
        }
    }

    var domain: MessageDomainEvent {
        get throws {
            guard let changed else {
                throw DomainError(.internalError, "Message event payload is empty")
            }

            return .changed(try changed.domain)
        }
    }

}


private struct MessageChangeEventDTO: Codable {

    let recipient: String
    let sourceRowId: Int64
    let occurredAt: Date
    let isFromMe: Bool
    let change: MessageChangeDTO

    init(_ domain: MessageChangeEvent) {
        recipient = domain.recipient
        sourceRowId = domain.sourceRowId
        occurredAt = domain.occurredAt
        isFromMe = domain.isFromMe
        change = MessageChangeDTO(domain.change)
    }

    var domain: MessageChangeEvent {
        get throws {
            MessageChangeEvent(
                recipient: recipient,
                sourceRowId: sourceRowId,
                occurredAt: occurredAt,
                isFromMe: isFromMe,
                change: try change.domain
            )
        }
    }

}


private struct MessageChangeDTO: Codable {

    var text: MessageTextDTO?
    var attachment: MessageAttachmentDTO?
    var reaction: MessageReactionDTO?
    var receipt: MessageReceiptUpdateDTO?

    init(_ domain: MessageChange) {
        switch domain {
        case .text(let value):
            text = MessageTextDTO(value)
        case .attachment(let value):
            attachment = MessageAttachmentDTO(value)
        case .reaction(let value):
            reaction = MessageReactionDTO(value)
        case .receipt(let value):
            receipt = MessageReceiptUpdateDTO(value)
        }
    }

    var domain: MessageChange {
        get throws {
            let present = [
                text.map { _ in "text" },
                attachment.map { _ in "attachment" },
                reaction.map { _ in "reaction" },
                receipt.map { _ in "receipt" },
            ].compactMap { $0 }

            guard present.count == 1 else {
                throw DomainError(.internalError, "Message change payload must contain exactly one change")
            }

            if let text {
                return .text(text.domain)
            }

            if let attachment {
                return .attachment(try attachment.domain)
            }

            if let reaction {
                return .reaction(reaction.domain)
            }

            if let receipt {
                return .receipt(receipt.domain)
            }

            throw DomainError(.internalError, "Message change payload is empty")
        }
    }

}


private struct MessageTextDTO: Codable {

    let messageId: String
    let text: String
    let replyToMessageId: String?

    init(_ domain: MessageText) {
        messageId = domain.messageId
        text = domain.text
        replyToMessageId = domain.replyToMessageId
    }

    var domain: MessageText {
        MessageText(
            messageId: messageId,
            text: text,
            replyToMessageId: replyToMessageId
        )
    }

}


private struct MessageAttachmentDTO: Codable {

    let messageId: String
    let kind: String
    let caption: String?
    let localPath: String?
    let fileSize: Int64?
    let title: String?
    let replyToMessageId: String?

    init(_ domain: MessageAttachment) {
        messageId = domain.messageId
        kind = domain.kind.rawValue
        caption = domain.caption
        localPath = domain.localPath
        fileSize = domain.fileSize
        title = domain.title
        replyToMessageId = domain.replyToMessageId
    }

    var domain: MessageAttachment {
        get throws {
            guard let attachmentKind = MessageAttachmentKind(rawValue: kind) else {
                throw DomainError(.internalError, "Unsupported message attachment kind")
                    .with("kind", kind)
            }

            return MessageAttachment(
                messageId: messageId,
                kind: attachmentKind,
                caption: caption,
                localPath: localPath,
                fileSize: fileSize,
                title: title,
                replyToMessageId: replyToMessageId
            )
        }
    }

}


private struct MessageReactionDTO: Codable {

    let messageId: String
    let emoji: String?
    let actorJid: String?
    let reactionId: String?

    init(_ domain: MessageReaction) {
        messageId = domain.messageId
        emoji = domain.emoji
        actorJid = domain.actorJid
        reactionId = domain.reactionId
    }

    var domain: MessageReaction {
        MessageReaction(
            messageId: messageId,
            emoji: emoji,
            actorJid: actorJid,
            reactionId: reactionId
        )
    }

}


private struct MessageReceiptUpdateDTO: Codable {

    let messageId: String
    let receiptDigest: String

    init(_ domain: MessageReceiptUpdate) {
        messageId = domain.messageId
        receiptDigest = domain.receiptDigest
    }

    var domain: MessageReceiptUpdate {
        MessageReceiptUpdate(
            messageId: messageId,
            receiptDigest: receiptDigest
        )
    }

}


private struct PollDomainEventDTO: Codable {

    var changed: PollChangeEventDTO?

    init(_ domain: PollDomainEvent) {
        switch domain {
        case .changed(let event):
            changed = PollChangeEventDTO(event)
        }
    }

    var domain: PollDomainEvent {
        get throws {
            guard let changed else {
                throw DomainError(.internalError, "Poll event payload is empty")
            }

            return .changed(try changed.domain)
        }
    }

}


private struct PollChangeEventDTO: Codable {

    let recipient: String
    let pollId: String
    let sourceRowId: Int64
    let occurredAt: Date
    let isFromMe: Bool
    let change: PollChangeDTO

    init(_ domain: PollChangeEvent) {
        recipient = domain.recipient
        pollId = domain.pollId
        sourceRowId = domain.sourceRowId
        occurredAt = domain.occurredAt
        isFromMe = domain.isFromMe
        change = PollChangeDTO(domain.change)
    }

    var domain: PollChangeEvent {
        get throws {
            PollChangeEvent(
                recipient: recipient,
                pollId: pollId,
                sourceRowId: sourceRowId,
                occurredAt: occurredAt,
                isFromMe: isFromMe,
                change: try change.domain
            )
        }
    }

}


private struct PollChangeDTO: Codable {

    var created: PollDTO?
    var updated: PollDTO?
    var voteChanged: PollDTO?
    var choicesChanged: PollDTO?

    init(_ domain: PollChange) {
        switch domain {
        case .created(let poll):
            created = PollDTO(poll)
        case .updated(let poll):
            updated = PollDTO(poll)
        case .voteChanged(let poll):
            voteChanged = PollDTO(poll)
        case .choicesChanged(let poll):
            choicesChanged = PollDTO(poll)
        }
    }

    var domain: PollChange {
        get throws {
            let present = [
                created.map { _ in "created" },
                updated.map { _ in "updated" },
                voteChanged.map { _ in "voteChanged" },
                choicesChanged.map { _ in "choicesChanged" },
            ].compactMap { $0 }

            guard present.count == 1 else {
                throw DomainError(.internalError, "Poll change payload must contain exactly one change")
            }

            if let created {
                return .created(try created.domain)
            }

            if let updated {
                return .updated(try updated.domain)
            }

            if let voteChanged {
                return .voteChanged(try voteChanged.domain)
            }

            if let choicesChanged {
                return .choicesChanged(try choicesChanged.domain)
            }

            throw DomainError(.internalError, "Poll change payload is empty")
        }
    }

}


private struct PollDTO: Codable {

    let pollId: String
    let question: String
    let choices: [PollChoiceDTO]
    let allowMultipleChoices: Bool
    let hideVoterNames: Bool

    init(_ domain: Poll) {
        pollId = domain.pollId
        question = domain.question
        choices = domain.choices.map(PollChoiceDTO.init)
        allowMultipleChoices = domain.allowMultipleChoices
        hideVoterNames = domain.hideVoterNames
    }

    var domain: Poll {
        get throws {
            Poll(
                pollId: pollId,
                question: question,
                choices: choices.map(\.domain),
                allowMultipleChoices: allowMultipleChoices,
                hideVoterNames: hideVoterNames
            )
        }
    }

}


private struct PollChoiceDTO: Codable {

    let index: Int
    let text: String
    let voteCount: Int

    init(_ domain: PollChoice) {
        index = domain.index
        text = domain.text
        voteCount = domain.voteCount
    }

    var domain: PollChoice {
        PollChoice(index: index, text: text, voteCount: voteCount)
    }

}
