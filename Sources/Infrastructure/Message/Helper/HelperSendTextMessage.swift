import Domain

package struct HelperSendTextMessage: SendTextMessage, Sendable {

    let client: any HelperCommandTransport

    package init(client: any HelperCommandTransport) {
        self.client = client
    }

    package func sendTextMessage(
        _ command: SendTextMessageCommand
    ) async throws -> String {
        var data: [String: JSONValue] = [
            "phone": .string(command.recipient)
        ]

        if let replyTo = command.replyTo {
            data["context"] = .object([
                "messageId": .string(replyTo),
                "messageIdType": .string("whatsapp.uniqueKey")
            ])
        }

        if isPlainText(command.content) {
            data["text"] = .string(command.text)
        } else {
            data["textDocument"] = .object(try serializeTextDocument(
                content: command.content
            ))
            data["renderOptions"] = .object([
                "markupPolicy": .string("preserve"),
                "normalizeLineEndings": .bool(true),
                "unsupportedPolicy": .string("reject")
            ])
        }

        if command.enableLinkPreview {
            data["sendOptions"] = .object([
                "linkPreview": .bool(true)
            ])
        }

        let response = try await client.sendCommand(action: "send-message", data: data)
        try HelperJSON.requireAccepted(response)

        return try HelperJSON.identifier(
            response["identifier"],
            field: "identifier",
            message: "Helper returned invalid message identifier"
        )
    }

}

private func isPlainText(_ content: [TextBlock]) -> Bool {
    guard content.count == 1, let block = content.first, block.type == .normal else {
        return false
    }

    guard block.text.count == 1, let run = block.text.first else {
        return false
    }

    return run.styles.isEmpty
}
