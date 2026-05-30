import Domain

package struct HelperSendReaction: SendReaction, Sendable {

    let client: any HelperCommandTransport

    package init(client: any HelperCommandTransport) {
        self.client = client
    }

    package func sendReaction(_ command: SendReactionCommand) async throws {
        let response = try await client.sendCommand(
            action: "send-reaction",
            data: [
                "uniqueKey": .string(command.messageId),
                "emoji": .string(command.emoji)
            ]
        )

        try HelperJSON.requireAccepted(response)
    }

}
