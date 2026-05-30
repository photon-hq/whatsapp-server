import Domain

package extension MessageService {

    func sendReaction(
        messageId: String,
        emoji: String,
        clientMessageId: String? = nil
    ) async throws -> MessageSnapshot {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)
        let command = SendReactionCommand(
            messageId: try IdentifierInput.required(messageId, field: "message_id"),
            emoji: try TextInput.trimmedNonEmpty(emoji, field: "emoji")
        )
        let previousReceipt = try await mutationReadback.receipt(
            forMessageId: command.messageId
        )

        return try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await sendReaction.sendReaction(command)

            guard let reaction = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.reaction(
                        matching: ReactionReadbackQuery(
                            messageId: command.messageId,
                            emoji: command.emoji,
                            previousReceiptDigest: previousReceipt?.receiptDigest
                        )
                    )
                }
            ) else {
                throw DomainError(.timeout, "Reaction did not become visible in ChatStorage in time")
                    .with("message_id", command.messageId)
            }

            guard let snapshot = try await mutationReadback.message(
                forMessageId: command.messageId
            ) else {
                throw DomainError(.timeout, "Reacted message did not become visible in ChatStorage in time")
                    .with("message_id", command.messageId)
            }

            return snapshot.withReactionReadback(reaction)
        }
    }

}

private extension MessageSnapshot {

    func withReactionReadback(_ readback: MessageReactionReadback) -> MessageSnapshot {
        MessageSnapshot(
            messageId: messageId,
            recipient: recipient,
            chatJid: chatJid,
            partnerName: partnerName,
            stanzaId: stanzaId,
            isFromMe: isFromMe,
            messageType: messageType,
            messageStatus: messageStatus,
            messageErrorStatus: messageErrorStatus,
            text: text,
            messageDate: messageDate,
            sentDate: sentDate,
            fromJid: fromJid,
            toJid: toJid,
            pushName: pushName,
            replyToMessageId: replyToMessageId,
            media: media,
            latestReaction: readback.reaction,
            receiptDigest: readback.receipt.receiptDigest
        )
    }

}
