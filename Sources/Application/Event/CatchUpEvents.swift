import Domain

package extension EventService {

    func catchUpEvents(
        afterSequence: UInt64? = nil
    ) async throws -> (headSequence: UInt64, events: EventSubscription<CaughtUpDomainEvent>) {
        let replayAfterSequence = afterSequence ?? 0
        let headSequence = try await eventStreaming.latestSequence()

        guard replayAfterSequence < headSequence else {
            return (
                headSequence,
                EventSubscription(
                    AsyncThrowingStream { continuation in
                        continuation.finish()
                    }
                )
            )
        }

        let replay = try await eventStreaming.replay(
            afterSequence: replayAfterSequence,
            throughSequence: headSequence
        )

        let messageProjector = messageProjector
        let pollProjector = pollProjector

        return (
            headSequence,
            replay.compactMap { envelope in
                if let message = messageProjector.project(envelope: envelope) {
                    return .message(message)
                }

                if let poll = pollProjector.project(envelope: envelope) {
                    return .poll(poll)
                }

                return nil
            }
        )
    }

}
