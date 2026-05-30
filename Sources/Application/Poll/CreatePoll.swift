import Domain
import Foundation

package extension PollService {

    func createPoll(
        recipient: String,
        question: String,
        choices: [String],
        allowMultipleChoices: Bool = false,
        hideVoterNames: Bool = false,
        closesAt: Date? = nil,
        clientMessageId: String? = nil
    ) async throws -> Poll {
        let preparedChoices = try choices.enumerated().map { index, choice in
            try TextInput.trimmedNonEmpty(choice, field: "choices[\(index)]")
        }

        guard preparedChoices.count >= 2 else {
            throw DomainError(.invalidArgument, "choices must contain at least two entries")
                .with("field", "choices")
        }

        guard Set(preparedChoices).count == preparedChoices.count else {
            throw DomainError(.invalidArgument, "choices must not contain duplicates")
                .with("field", "choices")
        }

        let command = CreatePollCommand(
            recipient: try RecipientInput.phone(recipient),
            question: try TextInput.trimmedNonEmpty(question, field: "question"),
            choices: preparedChoices,
            allowMultipleChoices: allowMultipleChoices,
            hideVoterNames: hideVoterNames,
            closesAt: try TimeInput.futureDate(closesAt, field: "closes_at")
        )

        let readback = try await mutationPolicy.execute(
            clientMessageId: try IdentifierInput.clientMessageId(clientMessageId)
        ) {
            let pollId = try await createPoll.createPoll(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.createdPoll(
                        matching: PollCreationReadbackQuery(
                            pollId: pollId,
                            recipient: command.recipient
                        )
                    )
                },
                matches: { $0.pollId == pollId }
            ) else {
                throw DomainError(.timeout, "Created poll did not become visible in ChatStorage in time")
                    .with("poll_id", pollId)
                    .with("recipient", command.recipient)
            }

            return readback
        }

        return readback.poll
    }

}
