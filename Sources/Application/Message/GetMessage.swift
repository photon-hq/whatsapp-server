import Domain

package extension MessageService {

    func getMessage(messageId: String) async throws -> MessageSnapshot {
        let messageId = try IdentifierInput.required(messageId, field: "message_id")
        guard let message = try await messageQuerying.getMessage(messageId: messageId) else {
            throw DomainError(.messageNotFound, "Message not found")
                .with("field", "message_id")
        }

        return message
    }

}
