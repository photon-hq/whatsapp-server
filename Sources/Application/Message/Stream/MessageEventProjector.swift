import Domain

package struct MessageEventProjector: Sendable {

    package init() {}

    package func project(
        envelope: DomainEventEnvelope,
        recipient: String? = nil
    ) -> SequencedMessageChange? {
        guard case .message(.changed(let event)) = envelope.event else {
            return nil
        }

        guard recipient == nil || event.recipient == recipient else {
            return nil
        }

        return SequencedMessageChange(
            sequence: envelope.sequence,
            observedAt: envelope.recordedAt,
            change: event
        )
    }

}
