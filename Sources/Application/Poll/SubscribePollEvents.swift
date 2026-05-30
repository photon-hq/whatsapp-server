import Domain

package extension PollService {

    func subscribeEvents(
        pollId: String? = nil
    ) async throws -> EventSubscription<SequencedPollChange> {
        let scope = try pollId.map {
            try IdentifierInput.required($0, field: "poll_id")
        }

        let upstream = try await eventStreaming.subscribe()
        let projector = eventProjector

        return upstream.compactMap { envelope in
            projector.project(
                envelope: envelope,
                pollId: scope
            )
        }
    }

}
