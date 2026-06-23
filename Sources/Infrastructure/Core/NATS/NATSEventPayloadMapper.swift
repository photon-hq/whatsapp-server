import Domain
import Foundation

package struct NATSEventPublication: Sendable, Equatable {

    package let subject: String
    package let payload: Data

    package init(subject: String, payload: Data) {
        self.subject = subject
        self.payload = payload
    }

}


package struct NATSEventPayloadMapper: Sendable {

    private let subjectPrefix: String
    private let deviceID: String?

    package init(subjectPrefix: String, deviceID: String? = nil) {
        self.subjectPrefix = Self.normalizeSubjectComponent(subjectPrefix)
        self.deviceID = deviceID.flatMap(Self.normalizeOptionalSubjectComponent)
    }

    package func publication(for envelope: DomainEventEnvelope) throws -> NATSEventPublication {
        let subject = subject(for: envelope.event.label)
        let payload = NATSEventPayload(envelope)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        return NATSEventPublication(
            subject: subject,
            payload: try encoder.encode(payload)
        )
    }

    private func subject(for eventType: String) -> String {
        ([subjectPrefix, deviceID, eventType].compactMap { $0 })
            .joined(separator: ".")
    }

    private static func normalizeSubjectComponent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        return trimmed.isEmpty ? "whatsapp.events" : trimmed
    }

    private static func normalizeOptionalSubjectComponent(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        return trimmed.isEmpty ? nil : trimmed
    }

}


private struct NATSEventPayload: Encodable {

    let sequence: UInt64
    let recordedAt: Date
    let type: String
    let recipient: String
    let sourceRowId: Int64
    let isFromMe: Bool
    let payload: EventPayload

    init(_ envelope: DomainEventEnvelope) {
        sequence = envelope.sequence
        recordedAt = envelope.recordedAt
        type = envelope.event.label

        switch envelope.event {
        case .message(.changed(let event)):
            recipient = event.recipient
            sourceRowId = event.sourceRowId
            isFromMe = event.isFromMe
            payload = .message(event.change)

        case .poll(.changed(let event)):
            recipient = event.recipient
            sourceRowId = event.sourceRowId
            isFromMe = event.isFromMe
            payload = .poll(event.change)
        }
    }

    enum CodingKeys: String, CodingKey {
        case sequence
        case recordedAt = "recorded_at"
        case type
        case recipient
        case sourceRowId = "source_row_id"
        case isFromMe = "is_from_me"
        case payload
    }

}


private enum EventPayload: Encodable {

    case message(MessageChange)
    case poll(PollChange)

    func encode(to encoder: Encoder) throws {
        switch self {
        case .message(let change):
            try MessageChangePayload(change).encode(to: encoder)

        case .poll(let change):
            try PollChangePayload(change).encode(to: encoder)
        }
    }

}


private struct MessageChangePayload: Encodable {

    let text: MessageTextPayload?
    let attachment: MessageAttachmentPayload?
    let reaction: MessageReactionPayload?
    let receipt: MessageReceiptPayload?

    init(_ change: MessageChange) {
        switch change {
        case .text(let value):
            text = MessageTextPayload(value)
            attachment = nil
            reaction = nil
            receipt = nil

        case .attachment(let value):
            text = nil
            attachment = MessageAttachmentPayload(value)
            reaction = nil
            receipt = nil

        case .reaction(let value):
            text = nil
            attachment = nil
            reaction = MessageReactionPayload(value)
            receipt = nil

        case .receipt(let value):
            text = nil
            attachment = nil
            reaction = nil
            receipt = MessageReceiptPayload(value)
        }
    }

}


private struct MessageTextPayload: Encodable {

    let messageId: String
    let text: String
    let replyToMessageId: String?

    init(_ value: MessageText) {
        messageId = value.messageId
        text = value.text
        replyToMessageId = value.replyToMessageId
    }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case text
        case replyToMessageId = "reply_to_message_id"
    }

}


private struct MessageAttachmentPayload: Encodable {

    let messageId: String
    let kind: String
    let caption: String?
    let localPath: String?
    let fileSize: Int64?
    let title: String?
    let replyToMessageId: String?

    init(_ value: MessageAttachment) {
        messageId = value.messageId
        kind = value.kind.rawValue
        caption = value.caption
        localPath = value.localPath
        fileSize = value.fileSize
        title = value.title
        replyToMessageId = value.replyToMessageId
    }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case kind
        case caption
        case localPath = "local_path"
        case fileSize = "file_size"
        case title
        case replyToMessageId = "reply_to_message_id"
    }

}


private struct MessageReactionPayload: Encodable {

    let messageId: String
    let emoji: String?
    let actorJid: String?
    let reactionId: String?

    init(_ value: MessageReaction) {
        messageId = value.messageId
        emoji = value.emoji
        actorJid = value.actorJid
        reactionId = value.reactionId
    }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case emoji
        case actorJid = "actor_jid"
        case reactionId = "reaction_id"
    }

}


private struct MessageReceiptPayload: Encodable {

    let messageId: String
    let receiptDigest: String

    init(_ value: MessageReceiptUpdate) {
        messageId = value.messageId
        receiptDigest = value.receiptDigest
    }

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case receiptDigest = "receipt_digest"
    }

}


private struct PollChangePayload: Encodable {

    let created: PollPayload?
    let updated: PollPayload?
    let voteChanged: PollPayload?
    let choicesChanged: PollPayload?

    init(_ change: PollChange) {
        switch change {
        case .created(let poll):
            created = PollPayload(poll)
            updated = nil
            voteChanged = nil
            choicesChanged = nil

        case .updated(let poll):
            created = nil
            updated = PollPayload(poll)
            voteChanged = nil
            choicesChanged = nil

        case .voteChanged(let poll):
            created = nil
            updated = nil
            voteChanged = PollPayload(poll)
            choicesChanged = nil

        case .choicesChanged(let poll):
            created = nil
            updated = nil
            voteChanged = nil
            choicesChanged = PollPayload(poll)
        }
    }

    enum CodingKeys: String, CodingKey {
        case created
        case updated
        case voteChanged = "vote_changed"
        case choicesChanged = "choices_changed"
    }

}


private struct PollPayload: Encodable {

    let pollId: String
    let question: String
    let choices: [PollChoicePayload]
    let allowMultipleChoices: Bool
    let hideVoterNames: Bool

    init(_ poll: Poll) {
        pollId = poll.pollId
        question = poll.question
        choices = poll.choices.map(PollChoicePayload.init)
        allowMultipleChoices = poll.allowMultipleChoices
        hideVoterNames = poll.hideVoterNames
    }

    enum CodingKeys: String, CodingKey {
        case pollId = "poll_id"
        case question
        case choices
        case allowMultipleChoices = "allow_multiple_choices"
        case hideVoterNames = "hide_voter_names"
    }

}


private struct PollChoicePayload: Encodable {

    let index: Int
    let text: String
    let voteCount: Int

    init(_ choice: PollChoice) {
        index = choice.index
        text = choice.text
        voteCount = choice.voteCount
    }

    enum CodingKeys: String, CodingKey {
        case index
        case text
        case voteCount = "vote_count"
    }

}
