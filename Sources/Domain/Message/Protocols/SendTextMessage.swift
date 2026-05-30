package protocol SendTextMessage: Sendable {

    func sendTextMessage(
        _ command: SendTextMessageCommand
    ) async throws -> String

}
