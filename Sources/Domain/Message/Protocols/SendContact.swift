package protocol SendContact: Sendable {

    func sendContact(
        _ command: SendContactCommand
    ) async throws

}
