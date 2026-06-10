package protocol SendSticker: Sendable {

    func sendSticker(
        _ command: SendStickerCommand
    ) async throws

}
