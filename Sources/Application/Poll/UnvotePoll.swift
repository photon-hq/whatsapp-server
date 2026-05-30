import Domain

package extension PollService {

    func unvotePoll(
        pollId: String,
        clientMessageId: String? = nil
    ) async throws -> Poll {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)
        let pollId = try IdentifierInput.required(pollId, field: "poll_id")
        let before = try await mutationReadback.currentPollUpdate(pollId: pollId)

        let readback = try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await unvotePoll.unvotePoll(pollId: pollId)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.updatedPoll(
                        matching: PollUpdateReadbackQuery(
                            pollId: pollId,
                            previousDigest: before?.digest
                        )
                    )
                },
                matches: { $0.isSamePoll(as: pollId) }
            ) else {
                throw DomainError(.timeout, "Poll unvote did not become visible in ChatStorage in time")
                    .with("poll_id", pollId)
            }

            return readback
        }

        return readback.poll
    }

}
