import Foundation
import GRDB
import XCTest
@testable import Domain
@testable import Infrastructure

final class EventStreamingTests: XCTestCase {

    func testCatchUpReplaysDurableEventsThroughFrozenHead() async throws {
        let stream = try makeEventStream()

        try await stream.publish(sampleEvent(text: "first"))
        try await stream.publish(sampleEvent(text: "second"))

        let replay = try await stream.replay(afterSequence: 0, throughSequence: 2)
        var iterator = replay.makeAsyncIterator()

        let first = try await iterator.next()
        let second = try await iterator.next()
        let end = try await iterator.next()

        XCTAssertEqual(first?.sequence, 1)
        XCTAssertEqual(second?.sequence, 2)
        XCTAssertNil(end)
    }

    func testResumeDrainsHistoryThenContinuesLive() async throws {
        let stream = try makeEventStream()

        try await stream.publish(sampleEvent(text: "one"))
        try await stream.publish(sampleEvent(text: "two"))

        let subscription = try await stream.resume(afterSequence: 1)
        var iterator = subscription.makeAsyncIterator()

        let replayed = try await iterator.next()
        XCTAssertEqual(replayed?.sequence, 2)

        try await stream.publish(sampleEvent(text: "three"))

        let live = try await iterator.next()
        XCTAssertEqual(live?.sequence, 3)
    }

    func testPublishStoresCursorAtomicallyWithEvent() async throws {
        let stream = try makeEventStream()

        try await stream.publish(
            [sampleEvent(text: "cursor")],
            cursor: NamedCursor(name: "observer", value: "row-10")
        )

        let value = try await stream.loadCursor(name: "observer")
        XCTAssertEqual(value, "row-10")
    }

    func testPersistedPayloadUsesVersionedEnvelope() async throws {
        let database = try ServerDatabase(path: temporaryDatabasePath())
        let log = DomainEventLog(database: database)

        _ = try await log.append(sampleEvent(text: "versioned"))

        let payload = try await database.read { db in
            try Data.fetchOne(db, sql: "SELECT payload FROM event_log WHERE sequence = 1")
        }

        let json = try XCTUnwrap(payload).jsonObject
        XCTAssertEqual(json["version"] as? Int, 1)
        XCTAssertNotNil(json["event"])
    }

    func testReplayRejectsUnversionedPayload() async throws {
        let database = try ServerDatabase(path: temporaryDatabasePath())
        let event = sampleEvent(text: "unversioned")
        let payload = try unversionedPayload(for: event)

        try await database.write { db in
            try db.execute(
                sql: "INSERT INTO event_log (recorded_at, payload) VALUES (?, ?)",
                arguments: [
                    Date(timeIntervalSince1970: 10),
                    payload,
                ]
            )
        }

        let log = DomainEventLog(database: database)
        let replay = await log.replay(afterSequence: 0, throughSequence: 1)
        var iterator = replay.makeAsyncIterator()

        do {
            _ = try await iterator.next()
            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .internalError)
            XCTAssertEqual(error.context["sequence"], "1")
        }
    }

    func testReplaysMessageAndPollEventsForStorage() async throws {
        let stream = try makeEventStream()

        try await stream.publish(sampleEvent(text: "message-1"))
        try await stream.publish(samplePollEvent())

        let replay = try await stream.replay(afterSequence: 0, throughSequence: 2)
        var iterator = replay.makeAsyncIterator()

        guard case .message(.changed(let message)) = try await iterator.next()?.event else {
            XCTFail("Expected message event")
            return
        }

        guard case .poll(.changed(let poll)) = try await iterator.next()?.event else {
            XCTFail("Expected poll event")
            return
        }

        let end = try await iterator.next()

        XCTAssertEqual(message.recipient, "15551619824")
        XCTAssertEqual(poll.pollId, "poll-1")
        XCTAssertNil(end)
    }

    func testReplaysMessageReactionReceiptAndPollVoteEvents() async throws {
        let stream = try makeEventStream()

        try await stream.publish(sampleReactionEvent())
        try await stream.publish(sampleReceiptEvent())
        try await stream.publish(samplePollVoteEvent())

        let replay = try await stream.replay(afterSequence: 0, throughSequence: 3)
        var iterator = replay.makeAsyncIterator()

        guard case .message(.changed(let reactionEvent)) = try await iterator.next()?.event,
              case .reaction(let reaction) = reactionEvent.change
        else {
            XCTFail("Expected reaction event")
            return
        }

        guard case .message(.changed(let receiptEvent)) = try await iterator.next()?.event,
              case .receipt(let receipt) = receiptEvent.change
        else {
            XCTFail("Expected receipt event")
            return
        }

        guard case .poll(.changed(let pollEvent)) = try await iterator.next()?.event,
              case .voteChanged(let poll) = pollEvent.change
        else {
            XCTFail("Expected poll vote event")
            return
        }

        XCTAssertEqual(reaction.emoji, "👍")
        XCTAssertEqual(receipt.receiptDigest, "digest-1")
        XCTAssertEqual(poll.choices.first?.voteCount, 1)
    }

    func testPersistedAttachmentRejectsUnknownKind() throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "event": [
                "message": [
                    "changed": [
                        "recipient": "15551619824",
                        "sourceRowId": 7,
                        "occurredAt": 7_000,
                        "isFromMe": false,
                        "change": [
                            "attachment": [
                                "messageId": "msg-attachment",
                                "kind": "unsupported",
                            ],
                        ],
                    ],
                ],
            ],
        ])

        XCTAssertThrowsError(try EventLogCodec.decode(payload)) { error in
            let domainError = error as? DomainError
            XCTAssertEqual(domainError?.code, .internalError)
            XCTAssertEqual(domainError?.context["kind"], "unsupported")
        }
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

    private func sampleEvent(text: String) -> DomainEvent {
        .message(
            .changed(
                MessageChangeEvent(
                    recipient: "15551619824",
                    sourceRowId: 1,
                    occurredAt: Date(timeIntervalSince1970: 1),
                    isFromMe: true,
                    change: .text(MessageText(
                        messageId: "jid_\(text)_1_0",
                        text: text,
                        replyToMessageId: nil
                    ))
                )
            )
        )
    }

    private func samplePollEvent() -> DomainEvent {
        .poll(.changed(PollChangeEvent(
            recipient: "15551619824",
            pollId: "poll-1",
            sourceRowId: 2,
            occurredAt: Date(timeIntervalSince1970: 2),
            isFromMe: true,
            change: .created(Poll(
                pollId: "poll-1",
                question: "Lunch?",
                choices: [PollChoice(index: 0, text: "Sushi", voteCount: 0)],
                allowMultipleChoices: false,
                hideVoterNames: false
            ))
        )))
    }

    private func samplePollVoteEvent() -> DomainEvent {
        .poll(.changed(PollChangeEvent(
            recipient: "15551619824",
            pollId: "poll-1",
            sourceRowId: 2,
            occurredAt: Date(timeIntervalSince1970: 2),
            isFromMe: true,
            change: .voteChanged(Poll(
                pollId: "poll-1",
                question: "Lunch?",
                choices: [PollChoice(index: 0, text: "Sushi", voteCount: 1)],
                allowMultipleChoices: false,
                hideVoterNames: false
            ))
        )))
    }

    private func sampleReactionEvent() -> DomainEvent {
        .message(.changed(MessageChangeEvent(
            recipient: "15551619824",
            sourceRowId: 5,
            occurredAt: Date(timeIntervalSince1970: 5),
            isFromMe: false,
            change: .reaction(MessageReaction(
                messageId: "msg-1",
                emoji: "👍",
                actorJid: "12345@lid",
                reactionId: "3B50485D7776329E4293"
            ))
        )))
    }

    private func sampleReceiptEvent() -> DomainEvent {
        .message(.changed(MessageChangeEvent(
            recipient: "15551619824",
            sourceRowId: 6,
            occurredAt: Date(timeIntervalSince1970: 6),
            isFromMe: true,
            change: .receipt(MessageReceiptUpdate(
                messageId: "msg-2",
                receiptDigest: "digest-1"
            ))
        )))
    }

    private func unversionedPayload(for event: DomainEvent) throws -> Data {
        switch event {
        case .message(.changed(let event)):
            let text = try XCTUnwrap(event.messageText)

            return try JSONSerialization.data(withJSONObject: [
                "message": [
                    "changed": [
                        "recipient": event.recipient,
                        "sourceRowId": event.sourceRowId,
                        "occurredAt": event.occurredAt.timeIntervalSinceReferenceDate,
                        "isFromMe": event.isFromMe,
                        "change": [
                            "text": [
                                "messageId": text.messageId,
                                "text": text.text,
                            ],
                        ],
                    ],
                ],
            ])

        default:
            throw XCTSkip("Legacy payload helper only supports text message events")
        }
    }

}

private extension MessageChangeEvent {

    var messageText: MessageText? {
        guard case .text(let text) = change else {
            return nil
        }

        return text
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
