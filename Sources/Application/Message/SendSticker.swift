import Domain
import Foundation

package extension MessageService {

    func sendSticker(
        recipient: String,
        data: [UInt8],
        emojis: [String] = [],
        accessibilityText: String? = nil,
        clientMessageId: String? = nil
    ) async throws -> MessageSnapshot {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)

        guard !data.isEmpty else {
            throw DomainError(.invalidArgument, "data is required")
                .with("field", "data")
        }

        let command = SendStickerCommand(
            recipient: try RecipientInput.phone(recipient),
            data: data,
            emojis: emojis,
            accessibilityText: try TextInput.optional(
                accessibilityText,
                field: "accessibility_text"
            )
        )
        let startedAt = Date()

        return try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await sendSticker.sendSticker(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.sentAttachment(
                        matching: SentAttachmentReadbackQuery(
                            recipient: command.recipient,
                            kind: .sticker,
                            notBefore: startedAt
                        )
                    )
                }
            ) else {
                throw DomainError(.timeout, "Sent sticker did not become visible in ChatStorage in time")
                    .with("recipient", command.recipient)
            }

            return readback
        }
    }

}
