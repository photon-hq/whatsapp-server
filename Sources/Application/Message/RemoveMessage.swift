import Domain
import Foundation

private let revokedPlaceholderMessageType = 14

package extension MessageService {

    func revokeMessage(
        messageId: String,
        clientMessageId: String? = nil
    ) async throws -> Bool {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)
        let messageId = try IdentifierInput.required(messageId, field: "message_id")

        _ = try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await revokeMessage.revokeMessage(messageId: messageId)
            try await awaitRemoval(
                messageId: messageId,
                detail: "Revoked message was still visible in ChatStorage after the readback window"
            )

            return messageId
        }

        return true
    }

    func deleteMessage(
        messageId: String,
        clientMessageId: String? = nil
    ) async throws -> Bool {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)
        let messageId = try IdentifierInput.required(messageId, field: "message_id")

        _ = try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await deleteMessage.deleteMessage(messageId: messageId)
            try await awaitRemoval(
                messageId: messageId,
                detail: "Deleted message was still visible in ChatStorage after the readback window"
            )

            return messageId
        }

        return true
    }

    private func awaitRemoval(
        messageId: String,
        detail: String
    ) async throws {
        let removed = try await ReadbackRetry.search(
            delaysNs: mutationReadbackDelaysNs,
            attempt: { () async throws -> Bool? in
                guard let snapshot = try await mutationReadback.message(
                    forMessageId: messageId
                ) else {
                    return true
                }

                // Revokes may keep a placeholder row instead of removing it.
                return snapshot.messageType == revokedPlaceholderMessageType
                    ? true
                    : nil
            }
        )

        guard removed == true else {
            throw DomainError(.timeout, detail)
                .with("message_id", messageId)
        }
    }

}
