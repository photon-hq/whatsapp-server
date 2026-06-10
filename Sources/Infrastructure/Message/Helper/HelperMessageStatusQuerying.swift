import Domain

package struct HelperMessageStatusQuerying: MessageStatusQuerying, Sendable {

    let client: any HelperCommandTransport

    package init(client: any HelperCommandTransport) {
        self.client = client
    }

    package func messageStatus(
        messageId: String
    ) async throws -> MessageDeliveryStatusSnapshot {
        let response = try await client.sendCommand(
            action: "get-message-status",
            data: [
                "uniqueKey": .string(messageId)
            ]
        )

        let label = try HelperJSON.string(response["status"], field: "status")

        return MessageDeliveryStatusSnapshot(
            messageId: messageId,
            status: MessageDeliveryStatus(rawValue: label) ?? .unknown,
            statusCode: try HelperJSON.int(response["statusCode"], field: "statusCode"),
            isFromMe: try HelperJSON.bool(response["fromMe"], field: "fromMe"),
            isSent: try HelperJSON.bool(response["isSent"], field: "isSent"),
            isError: try HelperJSON.bool(response["isError"], field: "isError"),
            isPlayed: try HelperJSON.bool(response["isPlayed"], field: "isPlayed"),
            text: response["text"]?.stringValue ?? ""
        )
    }

}
