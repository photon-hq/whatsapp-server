package protocol SendMediaMessage: Sendable {

    func sendMediaMessage(
        _ command: SendMediaMessageCommand
    ) async throws

}
