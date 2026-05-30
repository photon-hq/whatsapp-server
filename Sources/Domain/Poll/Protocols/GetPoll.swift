package protocol GetPoll: Sendable {

    func getPoll(
        pollId: String
    ) async throws -> Poll

}
