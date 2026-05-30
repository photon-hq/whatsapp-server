import Domain

package extension MessageService {

    func subscribeEvents(
        recipient: String? = nil
    ) async throws -> EventSubscription<SequencedMessageChange> {
        let scope = try recipient.map {
            try RecipientInput.phone($0)
        }

        let upstream = try await eventStreaming.subscribe()
        let projector = eventProjector

        return upstream.compactMap { envelope in
            projector.project(
                envelope: envelope,
                recipient: scope
            )
        }
    }

}
