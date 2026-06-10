import Domain

package struct HelperEditMessage: EditMessage, Sendable {

    let client: any HelperCommandTransport

    package init(client: any HelperCommandTransport) {
        self.client = client
    }

    package func editMessage(_ command: EditMessageCommand) async throws {
        let response = try await client.sendCommand(
            action: "edit-message",
            data: [
                "uniqueKey": .string(command.messageId),
                "text": .string(command.text)
            ]
        )

        try HelperJSON.requireAccepted(response)
    }

}
