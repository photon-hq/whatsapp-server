import Domain

package struct HelperCreatePoll: CreatePoll, Sendable {

    let client: any HelperCommandTransport

    package init(client: any HelperCommandTransport) {
        self.client = client
    }

    package func createPoll(
        _ command: CreatePollCommand
    ) async throws -> String {
        var data: [String: JSONValue] = [
            "phone": .string(command.recipient),
            "title": .string(command.question),
            "options": .array(command.choices.map { .string($0) }),
            "allowMultipleAnswers": .bool(command.allowMultipleChoices),
            "hideParticipantName": .bool(command.hideVoterNames)
        ]

        if let closesAt = command.closesAt {
            data["endTime"] = .number(closesAt.timeIntervalSince1970)
        }

        let response = try await client.sendCommand(action: "create-poll", data: data)
        try HelperJSON.requireAccepted(response)

        return try HelperJSON.identifier(
            response["identifier"],
            field: "identifier",
            message: "Helper returned invalid poll identifier"
        )
    }

}
