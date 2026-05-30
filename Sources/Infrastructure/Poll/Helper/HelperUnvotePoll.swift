import Domain

package struct HelperUnvotePoll: UnvotePoll, Sendable {

    let client: any HelperCommandTransport
    let resolver: ChatStoragePollKeyResolver

    package init(
        client: any HelperCommandTransport,
        resolver: ChatStoragePollKeyResolver
    ) {
        self.client = client
        self.resolver = resolver
    }

    package func unvotePoll(pollId: String) async throws {
        let pollId = try await resolver.localPollId(for: pollId)

        let response = try await client.sendCommand(
            action: "unvote-poll",
            data: ["uniqueKey": .string(pollId)]
        )

        try HelperJSON.requireAccepted(response)
    }

}
