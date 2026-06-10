package protocol SendAudio: Sendable {

    func sendAudio(
        _ command: SendAudioCommand
    ) async throws

}
