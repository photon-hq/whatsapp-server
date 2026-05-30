import Domain
import Foundation

package extension MessageService {

    func sendMediaMessage(
        recipient: String,
        type: MediaType,
        data: [UInt8],
        caption: String? = nil,
        accessibilityText: String? = nil,
        clientMessageId: String? = nil
    ) async throws -> MessageSnapshot {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)

        guard !data.isEmpty else {
            throw DomainError(.invalidArgument, "data is required")
                .with("field", "data")
        }

        let command = SendMediaMessageCommand(
            recipient: try RecipientInput.phone(recipient),
            type: type,
            data: data,
            caption: try TextInput.optional(caption, field: "caption"),
            accessibilityText: try TextInput.optional(
                accessibilityText,
                field: "accessibility_text"
            )
        )
        let startedAt = Date()

        return try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await sendMediaMessage.sendMediaMessage(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.sentMedia(
                        matching: SentMediaReadbackQuery(
                            recipient: command.recipient,
                            type: command.type,
                            caption: command.caption,
                            notBefore: startedAt
                        )
                    )
                }
            ) else {
                throw DomainError(.timeout, "Sent media did not become visible in ChatStorage in time")
                    .with("recipient", command.recipient)
                    .with("type", command.type.rawValue)
            }

            return readback
        }
    }

}
