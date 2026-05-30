package protocol SendReaction: Sendable {

    func sendReaction(
        _ command: SendReactionCommand
    ) async throws

}
