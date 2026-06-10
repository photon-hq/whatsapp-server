import Domain

package struct HelperDeleteMessage: DeleteMessage, Sendable {

    let client: any HelperCommandTransport

    package init(client: any HelperCommandTransport) {
        self.client = client
    }

    package func deleteMessage(messageId: String) async throws {
        let response = try await client.sendCommand(
            action: "delete-message",
            data: [
                "uniqueKey": .string(messageId)
            ]
        )

        try HelperJSON.requireAccepted(response)
    }

}
