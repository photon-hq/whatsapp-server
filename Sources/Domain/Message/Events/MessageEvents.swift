import Foundation

package enum MessageDomainEvent: Sendable, Equatable {

    case changed(MessageChangeEvent)

}


package struct MessageChangeEvent: Sendable, Equatable {

    package let recipient: String
    package let sourceRowId: Int64
    package let occurredAt: Date
    package let isFromMe: Bool
    package let change: MessageChange

    package init(
        recipient: String,
        sourceRowId: Int64,
        occurredAt: Date,
        isFromMe: Bool,
        change: MessageChange
    ) {
        self.recipient = recipient
        self.sourceRowId = sourceRowId
        self.occurredAt = occurredAt
        self.isFromMe = isFromMe
        self.change = change
    }

}


package struct SequencedMessageChange: Sendable, Equatable {

    package let sequence: UInt64
    package let observedAt: Date
    package let change: MessageChangeEvent

    package init(
        sequence: UInt64,
        observedAt: Date,
        change: MessageChangeEvent
    ) {
        self.sequence = sequence
        self.observedAt = observedAt
        self.change = change
    }

}
