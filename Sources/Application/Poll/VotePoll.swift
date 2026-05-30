import Domain

package extension PollService {

    func votePoll(
        pollId: String,
        choiceIndexes: [Int],
        clientMessageId: String? = nil
    ) async throws -> Poll {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)
        let pollId = try IdentifierInput.required(pollId, field: "poll_id")

        let command = VotePollCommand(
            pollId: pollId,
            choiceIndexes: try NumberInput.nonNegativeIndexes(
                choiceIndexes,
                field: "choice_indexes"
            )
        )

        let before = try await mutationReadback.currentPollUpdate(pollId: pollId)

        let readback = try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await votePoll.votePoll(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.updatedPoll(
                        matching: PollUpdateReadbackQuery(
                            pollId: command.pollId,
                            previousDigest: before?.digest
                        )
                    )
                },
                matches: { $0.isSamePoll(as: command.pollId) }
            ) else {
                throw DomainError(.timeout, "Poll vote did not become visible in ChatStorage in time")
                    .with("poll_id", command.pollId)
            }

            return readback
        }

        return readback.poll
    }

}
