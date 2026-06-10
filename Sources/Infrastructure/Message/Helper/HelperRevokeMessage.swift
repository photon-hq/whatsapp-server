import Domain

package struct HelperRevokeMessage: RevokeMessage, Sendable {

    let client: any HelperCommandTransport

    package init(client: any HelperCommandTransport) {
        self.client = client
    }

    package func revokeMessage(messageId: String) async throws {
        let response = try await client.sendCommand(
            action: "revoke-message",
            data: [
                "uniqueKey": .string(messageId)
            ]
        )

        try HelperJSON.requireAccepted(response)
    }

}
