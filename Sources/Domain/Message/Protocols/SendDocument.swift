package protocol SendDocument: Sendable {

    func sendDocument(
        _ command: SendDocumentCommand
    ) async throws

}
