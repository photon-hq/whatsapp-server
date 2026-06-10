import Domain
import Foundation

package extension MessageService {

    func sendAudio(
        recipient: String,
        data: [UInt8],
        mimeType: String? = nil,
        clientMessageId: String? = nil
    ) async throws -> MessageSnapshot {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)

        guard !data.isEmpty else {
            throw DomainError(.invalidArgument, "data is required")
                .with("field", "data")
        }

        if let mimeType, !mimeType.lowercased().hasPrefix("audio/") {
            throw DomainError(.invalidArgument, "mime_type must be an audio/* type")
                .with("field", "mime_type")
        }

        let command = SendAudioCommand(
            recipient: try RecipientInput.phone(recipient),
            data: data,
            mimeType: try TextInput.optional(mimeType, field: "mime_type")
        )
        let startedAt = Date()

        return try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await sendAudio.sendAudio(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.sentAttachment(
                        matching: SentAttachmentReadbackQuery(
                            recipient: command.recipient,
                            kind: .audio,
                            notBefore: startedAt
                        )
                    )
                }
            ) else {
                throw DomainError(.timeout, "Sent audio did not become visible in ChatStorage in time")
                    .with("recipient", command.recipient)
            }

            return readback
        }
    }

}
