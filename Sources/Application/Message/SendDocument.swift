import Domain
import Foundation

package extension MessageService {

    func sendDocument(
        recipient: String,
        data: [UInt8],
        fileName: String? = nil,
        mimeType: String? = nil,
        caption: String? = nil,
        clientMessageId: String? = nil
    ) async throws -> MessageSnapshot {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)

        guard !data.isEmpty else {
            throw DomainError(.invalidArgument, "data is required")
                .with("field", "data")
        }

        let command = SendDocumentCommand(
            recipient: try RecipientInput.phone(recipient),
            data: data,
            fileName: try TextInput.optional(fileName, field: "file_name"),
            mimeType: try TextInput.optional(mimeType, field: "mime_type"),
            caption: try TextInput.optional(caption, field: "caption")
        )
        let startedAt = Date()

        return try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await sendDocument.sendDocument(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.sentAttachment(
                        matching: SentAttachmentReadbackQuery(
                            recipient: command.recipient,
                            kind: .document,
                            caption: command.caption,
                            notBefore: startedAt
                        )
                    )
                }
            ) else {
                throw DomainError(.timeout, "Sent document did not become visible in ChatStorage in time")
                    .with("recipient", command.recipient)
            }

            return readback
        }
    }

}
