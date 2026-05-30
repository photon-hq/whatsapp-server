import Domain

package struct PollEventProjector: Sendable {

    package init() {}

    package func project(
        envelope: DomainEventEnvelope,
        pollId: String? = nil
    ) -> SequencedPollChange? {
        guard case .poll(.changed(let change)) = envelope.event else {
            return nil
        }

        guard pollId == nil || change.pollId == pollId else {
            return nil
        }

        return SequencedPollChange(
            sequence: envelope.sequence,
            observedAt: envelope.recordedAt,
            change: change
        )
    }

}
