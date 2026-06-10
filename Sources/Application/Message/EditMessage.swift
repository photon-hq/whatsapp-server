import Domain
import Foundation

package extension MessageService {

    func editMessage(
        messageId: String,
        text: String,
        clientMessageId: String? = nil
    ) async throws -> MessageSnapshot {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)
        let messageId = try IdentifierInput.required(messageId, field: "message_id")

        guard !text.isEmpty else {
            throw DomainError(.invalidArgument, "text is required")
                .with("field", "text")
        }

        let command = EditMessageCommand(messageId: messageId, text: text)

        return try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await editMessage.editMessage(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: { () async throws -> MessageSnapshot? in
                    guard let snapshot = try await mutationReadback.message(
                        forMessageId: command.messageId
                    ), snapshot.text == command.text else {
                        return nil
                    }

                    return snapshot
                }
            ) else {
                throw DomainError(.timeout, "Edited message text did not become visible in ChatStorage in time")
                    .with("message_id", command.messageId)
            }

            return readback
        }
    }

}
