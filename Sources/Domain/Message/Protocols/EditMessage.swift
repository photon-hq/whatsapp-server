package protocol EditMessage: Sendable {

    func editMessage(
        _ command: EditMessageCommand
    ) async throws

}
