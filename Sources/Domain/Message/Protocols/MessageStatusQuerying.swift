package protocol MessageStatusQuerying: Sendable {

    func messageStatus(
        messageId: String
    ) async throws -> MessageDeliveryStatusSnapshot

}
