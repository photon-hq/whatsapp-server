import Domain

package extension MessageService {

    func getMessageStatus(
        messageId: String
    ) async throws -> MessageDeliveryStatusSnapshot {
        let messageId = try IdentifierInput.required(messageId, field: "message_id")

        return try await messageStatusQuerying.messageStatus(messageId: messageId)
    }

}
