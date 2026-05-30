import XCTest
@testable import Domain
@testable import Infrastructure

final class PollHelperAdapterTests: XCTestCase {

    func testPollAdapterMapsCreatePollToHelperPayload() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("poll-1"),
            "allowMultipleAnswers": .bool(true),
        ])
        let adapter = HelperCreatePoll(client: transport)

        _ = try await adapter.createPoll(
            CreatePollCommand(
                recipient: "11234567890",
                question: "Lunch?",
                choices: ["Sushi", "Pizza"],
                allowMultipleChoices: true
            )
        )

        let action = await transport.lastAction
        XCTAssertEqual(action, "create-poll")

        let data = await transport.lastData
        XCTAssertEqual(data?["allowMultipleAnswers"]?.boolValue, true)
        XCTAssertEqual(data?["title"]?.stringValue, "Lunch?")
        XCTAssertEqual(data?["options"]?.arrayValue?.map(\.stringValue), ["Sushi", "Pizza"])
    }

    func testPollAdapterRejectsMissingCreateIdentifier() async {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "allowMultipleAnswers": .bool(true),
        ])
        let adapter = HelperCreatePoll(client: transport)

        do {
            _ = try await adapter.createPoll(
                CreatePollCommand(
                    recipient: "11234567890",
                    question: "Lunch?",
                    choices: ["Sushi", "Pizza"]
                )
            )

            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .internalError)
            XCTAssertEqual(error.context["field"], "identifier")
        } catch {
            XCTFail("Expected DomainError")
        }
    }

    func testPollAdapterResolvesVotePollIdBeforeCallingHelper() async throws {
        let resolver = ChatStoragePollKeyResolver(
            database: try ChatStorageDatabase(path: try makePollKeyDatabase())
        )
        let transport = RecordingTransport(response: ["accepted": .bool(true)])
        let adapter = HelperVotePoll(client: transport, resolver: resolver)

        try await adapter.votePoll(
            VotePollCommand(
                pollId: "154881402888340@lid_3BB730B6CA80FF723BFE_1_0",
                choiceIndexes: [0, 2]
            )
        )

        let action = await transport.lastAction
        XCTAssertEqual(action, "vote-poll")

        let data = await transport.lastData
        XCTAssertEqual(data?["uniqueKey"]?.stringValue, "48761485131844@lid_3BB730B6CA80FF723BFE_0_0")
        XCTAssertEqual(data?["optionIndexes"]?.arrayValue?.compactMap(\.intValue), [0, 2])
    }

    func testPollAdapterResolvesUnvotePollIdBeforeCallingHelper() async throws {
        let resolver = ChatStoragePollKeyResolver(
            database: try ChatStorageDatabase(path: try makePollKeyDatabase())
        )
        let transport = RecordingTransport(response: ["accepted": .bool(true)])
        let adapter = HelperUnvotePoll(client: transport, resolver: resolver)

        try await adapter.unvotePoll(
            pollId: "154881402888340@lid_3BB730B6CA80FF723BFE_1_0"
        )

        let action = await transport.lastAction
        XCTAssertEqual(action, "unvote-poll")

        let data = await transport.lastData
        XCTAssertEqual(data?["uniqueKey"]?.stringValue, "48761485131844@lid_3BB730B6CA80FF723BFE_0_0")
    }

}
