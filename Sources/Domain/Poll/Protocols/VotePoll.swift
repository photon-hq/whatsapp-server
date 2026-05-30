package protocol VotePoll: Sendable {

    func votePoll(
        _ command: VotePollCommand
    ) async throws

}
