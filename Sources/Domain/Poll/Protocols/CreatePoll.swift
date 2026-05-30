package protocol CreatePoll: Sendable {

    func createPoll(
        _ command: CreatePollCommand
    ) async throws -> String

}
