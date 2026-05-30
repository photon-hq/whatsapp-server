import Foundation

package struct DomainEventEnvelope: Sendable, Equatable {

    package let sequence: UInt64
    package let recordedAt: Date
    package let event: DomainEvent

    package init(
        sequence: UInt64,
        recordedAt: Date,
        event: DomainEvent
    ) {
        self.sequence = sequence
        self.recordedAt = recordedAt
        self.event = event
    }

}
