import Foundation

package enum PollDomainEvent: Sendable, Equatable {

    case changed(PollChangeEvent)

}


package struct PollChangeEvent: Sendable, Equatable {

    package let recipient: String
    package let pollId: String
    package let sourceRowId: Int64
    package let occurredAt: Date
    package let isFromMe: Bool
    package let change: PollChange

    package init(
        recipient: String,
        pollId: String,
        sourceRowId: Int64,
        occurredAt: Date,
        isFromMe: Bool,
        change: PollChange
    ) {
        self.recipient = recipient
        self.pollId = pollId
        self.sourceRowId = sourceRowId
        self.occurredAt = occurredAt
        self.isFromMe = isFromMe
        self.change = change
    }

}


package struct SequencedPollChange: Sendable, Equatable {

    package let sequence: UInt64
    package let observedAt: Date
    package let change: PollChangeEvent

    package init(
        sequence: UInt64,
        observedAt: Date,
        change: PollChangeEvent
    ) {
        self.sequence = sequence
        self.observedAt = observedAt
        self.change = change
    }

}
