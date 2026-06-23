import Foundation
import GRDB
import XCTest
@testable import Domain
@testable import Infrastructure

final class NATSEventRelayTests: XCTestCase {

    func testMapperBuildsMessageSubjectAndPayload() throws {
        let mapper = NATSEventPayloadMapper(
            subjectPrefix: "whatsapp.events",
            deviceID: "device-a"
        )
        let envelope = DomainEventEnvelope(
            sequence: 42,
            recordedAt: Date(timeIntervalSince1970: 0),
            event: sampleTextEvent()
        )

        let publication = try mapper.publication(for: envelope)
        let json = try publication.payload.jsonObject
        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        let text = try XCTUnwrap(payload["text"] as? [String: Any])

        XCTAssertEqual(publication.subject, "whatsapp.events.device-a.message.changed")
        XCTAssertEqual(json["sequence"] as? Int, 42)
        XCTAssertEqual(json["type"] as? String, "message.changed")
        XCTAssertEqual(json["recipient"] as? String, "15551619824")
        XCTAssertEqual(json["source_row_id"] as? Int, 11)
        XCTAssertEqual(json["is_from_me"] as? Bool, false)
        XCTAssertEqual(text["message_id"] as? String, "msg-1")
        XCTAssertEqual(text["text"] as? String, "hello")
    }

    func testMapperBuildsPollVotePayload() throws {
        let mapper = NATSEventPayloadMapper(subjectPrefix: ".whatsapp.events.")
        let envelope = DomainEventEnvelope(
            sequence: 7,
            recordedAt: Date(timeIntervalSince1970: 10),
            event: samplePollVoteEvent()
        )

        let publication = try mapper.publication(for: envelope)
        let json = try publication.payload.jsonObject
        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        let voteChanged = try XCTUnwrap(payload["vote_changed"] as? [String: Any])
        let choices = try XCTUnwrap(voteChanged["choices"] as? [[String: Any]])

        XCTAssertEqual(publication.subject, "whatsapp.events.poll.changed")
        XCTAssertEqual(json["type"] as? String, "poll.changed")
        XCTAssertEqual(voteChanged["poll_id"] as? String, "poll-1")
        XCTAssertEqual(voteChanged["question"] as? String, "Lunch?")
        XCTAssertEqual(voteChanged["allow_multiple_choices"] as? Bool, true)
        XCTAssertEqual(choices.first?["text"] as? String, "Sushi")
        XCTAssertEqual(choices.first?["vote_count"] as? Int, 1)
    }

    func testRelayPublishesReplayAndAdvancesCursor() async throws {
        let stream = try makeEventStream()
        let publisher = RecordingNATSPublisher()
        let relay = NATSEventRelay(
            configuration: .init(
                url: URL(string: "nats://localhost:4222")!,
                subjectPrefix: "whatsapp.events",
                cursorName: "nats_test_cursor",
                retryDelay: .milliseconds(1)
            ),
            eventStreaming: stream,
            publisher: publisher
        )

        try await stream.publish(sampleTextEvent())
        try await stream.publish(samplePollVoteEvent())

        let count = try await relay.publishAvailableEventsOnce()
        let cursor = try await stream.loadCursor(name: "nats_test_cursor")
        let subjects = await publisher.subjects()

        XCTAssertEqual(count, 2)
        XCTAssertEqual(cursor, "2")
        XCTAssertEqual(subjects, [
            "whatsapp.events.message.changed",
            "whatsapp.events.poll.changed",
        ])
    }

    func testRelayDoesNotAdvanceCursorWhenPublishFails() async throws {
        let stream = try makeEventStream()
        let publisher = RecordingNATSPublisher(failPublish: true)
        let relay = NATSEventRelay(
            configuration: .init(
                url: URL(string: "nats://localhost:4222")!,
                subjectPrefix: "whatsapp.events",
                cursorName: "nats_test_cursor",
                retryDelay: .milliseconds(1)
            ),
            eventStreaming: stream,
            publisher: publisher
        )

        try await stream.publish(sampleTextEvent())

        do {
            _ = try await relay.publishAvailableEventsOnce()
            XCTFail("Expected publish failure")
        } catch NATSPublisherTestError.publishFailed {
        }

        let cursor = try await stream.loadCursor(name: "nats_test_cursor")
        let subjects = await publisher.subjects()

        XCTAssertNil(cursor)
        XCTAssertEqual(subjects, [])
    }

    private func makeEventStream() throws -> DomainEventStream {
        let database = try ServerDatabase(path: temporaryDatabasePath())
        let log = DomainEventLog(database: database)

        return DomainEventStream(eventLog: log)
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("server.db")
            .path
    }

    private func sampleTextEvent() -> DomainEvent {
        .message(.changed(MessageChangeEvent(
            recipient: "15551619824",
            sourceRowId: 11,
            occurredAt: Date(timeIntervalSince1970: 1),
            isFromMe: false,
            change: .text(MessageText(
                messageId: "msg-1",
                text: "hello",
                replyToMessageId: nil
            ))
        )))
    }

    private func samplePollVoteEvent() -> DomainEvent {
        .poll(.changed(PollChangeEvent(
            recipient: "15551619824",
            pollId: "poll-1",
            sourceRowId: 12,
            occurredAt: Date(timeIntervalSince1970: 2),
            isFromMe: false,
            change: .voteChanged(Poll(
                pollId: "poll-1",
                question: "Lunch?",
                choices: [PollChoice(index: 0, text: "Sushi", voteCount: 1)],
                allowMultipleChoices: true,
                hideVoterNames: false
            ))
        )))
    }

}


private enum NATSPublisherTestError: Error {
    case publishFailed
}


private actor RecordingNATSPublisher: NATSPublishing {

    private let failPublish: Bool
    private var publications: [(subject: String, payload: Data)] = []

    init(failPublish: Bool = false) {
        self.failPublish = failPublish
    }

    func connect() async throws {
    }

    func publish(_ payload: Data, subject: String) async throws {
        if failPublish {
            throw NATSPublisherTestError.publishFailed
        }

        publications.append((subject: subject, payload: payload))
    }

    func close() async {
    }

    func subjects() -> [String] {
        publications.map(\.subject)
    }

}


private extension Data {

    var jsonObject: [String: Any] {
        get throws {
            try XCTUnwrap(
                JSONSerialization.jsonObject(with: self) as? [String: Any]
            )
        }
    }

}
