import Domain

package extension MessageService {

    func sendTextMessage(
        recipient: String,
        content: [TextBlock],
        replyTo: String? = nil,
        enableLinkPreview: Bool = false,
        clientMessageId: String? = nil
    ) async throws -> MessageSnapshot {
        let body = try TextInput.textContent(content)

        let replyTarget = try replyTo.map {
            try IdentifierInput.required($0, field: "reply_to")
        }

        let command = SendTextMessageCommand(
            recipient: try RecipientInput.phone(recipient),
            content: body,
            replyTo: replyTarget,
            enableLinkPreview: enableLinkPreview
        )

        return try await mutationPolicy.execute(
            clientMessageId: try IdentifierInput.clientMessageId(clientMessageId)
        ) {
            let messageId = try await sendTextMessage.sendTextMessage(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.sentText(
                        matching: SentTextReadbackQuery(
                            messageId: messageId,
                            recipient: command.recipient,
                            text: command.text,
                            replyToMessageId: command.replyTo
                        )
                    )
                }
            ) else {
                throw DomainError(.timeout, "Sent text did not become visible in ChatStorage in time")
                    .with("message_id", messageId)
                    .with("recipient", command.recipient)
            }

            return readback
        }
    }
}
