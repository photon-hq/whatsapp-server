import Domain

package struct HelperVotePoll: VotePoll, Sendable {

    let client: any HelperCommandTransport
    let resolver: ChatStoragePollKeyResolver

    package init(
        client: any HelperCommandTransport,
        resolver: ChatStoragePollKeyResolver
    ) {
        self.client = client
        self.resolver = resolver
    }

    package func votePoll(_ command: VotePollCommand) async throws {
        let pollId = try await resolver.localPollId(for: command.pollId)

        let response = try await client.sendCommand(
            action: "vote-poll",
            data: [
                "uniqueKey": .string(pollId),
                "optionIndexes": .array(command.choiceIndexes.map { .number(Double($0)) })
            ]
        )

        try HelperJSON.requireAccepted(response)
    }

}
