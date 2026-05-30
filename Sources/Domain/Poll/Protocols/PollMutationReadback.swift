package protocol PollMutationReadback: Sendable {

    func createdPoll(
        matching query: PollCreationReadbackQuery
    ) async throws -> PollMutationReadbackResult?

    func currentPollUpdate(
        pollId: String
    ) async throws -> PollMutationReadbackResult?

    func updatedPoll(
        matching query: PollUpdateReadbackQuery
    ) async throws -> PollMutationReadbackResult?

}
