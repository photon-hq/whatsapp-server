import XCTest
@testable import Application
@testable import Domain

private actor MessageCommandRecorder:
    SendTextMessage,
    SendMediaMessage,
    SendReaction,
    MessageQuerying,
    MessageMutationReadback
{

    private(set) var lastTextCommand: SendTextMessageCommand?
    private(set) var lastMediaCommand: SendMediaMessageCommand?
    private(set) var lastReactionCommand: SendReactionCommand?
    private(set) var textSendCount = 0
    private(set) var reactionSendCount = 0
    private(set) var receiptReadCount = 0
    var textSendError: (any Error)?
    var sentTextReadback: MessageSnapshot? = MessageSnapshot(
        messageId: "msg-1",
        recipient: "11234567890",
        isFromMe: true
    )
    var sentMediaReadback: MessageSnapshot? = MessageSnapshot(
        messageId: "media-1",
        recipient: "11234567890",
        isFromMe: true
    )
    var previousReceiptReadback: MessageReceiptReadback? = MessageReceiptReadback(
        messageId: "msg-1",
        receiptDigest: "old"
    )
    var reactionReadback: MessageReceiptReadback? = MessageReceiptReadback(
        messageId: "msg-1",
        receiptDigest: "new"
    )
    var reactedMessageReadback: MessageSnapshot? = MessageSnapshot(
        messageId: "msg-1",
        recipient: "11234567890",
        isFromMe: false
    )

    func sendTextMessage(_ command: SendTextMessageCommand) async throws -> String {
        if let textSendError {
            throw textSendError
        }

        lastTextCommand = command
        textSendCount += 1
        return "msg-1"
    }

    func sendMediaMessage(_ command: SendMediaMessageCommand) async throws {
        lastMediaCommand = command
    }

    func sendReaction(_ command: SendReactionCommand) async throws {
        lastReactionCommand = command
        reactionSendCount += 1
    }

    func getMessage(messageId: String) async throws -> MessageSnapshot? {
        MessageSnapshot(messageId: messageId, recipient: "11234567890", isFromMe: true)
    }

    func listRecentMessages(query: RecentMessagesQuery) async throws -> MessagePageSlice {
        MessagePageSlice(
            entries: [
                MessagePageEntry(
                    message: MessageSnapshot(messageId: "recent-1", recipient: "11234567890", isFromMe: true),
                    cursor: MessagePageCursor(sort: 1, rowId: 1)
                )
            ],
            snapshotRowId: 1,
            nextCursor: MessagePageCursor(sort: 1, rowId: 1)
        )
    }

    func listChatMessages(query: ChatMessagesQuery) async throws -> MessagePageSlice {
        try await listRecentMessages(query: RecentMessagesQuery(pageSize: query.pageSize))
    }

    func sentText(
        matching query: SentTextReadbackQuery
    ) async throws -> MessageSnapshot? {
        sentTextReadback
    }

    func sentMedia(
        matching query: SentMediaReadbackQuery
    ) async throws -> MessageSnapshot? {
        sentMediaReadback
    }

    func message(
        forMessageId messageId: String
    ) async throws -> MessageSnapshot? {
        reactedMessageReadback
    }

    func receipt(
        forMessageId messageId: String
    ) async throws -> MessageReceiptReadback? {
        receiptReadCount += 1
        return previousReceiptReadback
    }

    func reaction(
        matching query: ReactionReadbackQuery
    ) async throws -> MessageReactionReadback? {
        guard let reactionReadback else {
            return nil
        }

        return MessageReactionReadback(
            receipt: reactionReadback,
            reaction: MessageReactionSnapshot(messageId: query.messageId, emoji: query.emoji)
        )
    }

}

final class MessageServiceTests: XCTestCase {

    func testSendTextMessageBuildsCommand() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        _ = try await service.sendTextMessage(
            recipient: "11234567890",
            content: [TextBlock(text: [TextRun(text: "  hello  ")])]
        )

        let command = await recorder.lastTextCommand
        XCTAssertEqual(command?.recipient, "11234567890")
        XCTAssertEqual(command?.text, "  hello  ")
        XCTAssertEqual(command?.content, [
            TextBlock(text: [TextRun(text: "  hello  ")])
        ])
        XCTAssertEqual(command?.enableLinkPreview, false)
    }

    func testSendTextMessageBuildsStructuredContentCommand() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        _ = try await service.sendTextMessage(
            recipient: "11234567890",
            content: [
                TextBlock(text: [
                    TextRun(text: "Hello "),
                    TextRun(text: "world", styles: [.bold, .italic, .bold])
                ]),
                TextBlock(type: .bullet, text: [
                    TextRun(text: "Pay "),
                    TextRun(text: "today", styles: [.bold])
                ])
            ]
        )

        let command = await recorder.lastTextCommand
        XCTAssertEqual(command?.text, "Hello world\nPay today")
        XCTAssertEqual(command?.content[0].text[1].styles, [.bold, .italic])
        XCTAssertEqual(command?.content[1].type, .bullet)
    }

    func testSendTextMessageRequiresChatStorageReadback() async throws {
        let recorder = MessageCommandRecorder()
        await recorder.setSentTextReadback(nil)
        let service = messageService(recorder)

        do {
            _ = try await service.sendTextMessage(
                recipient: "11234567890",
                content: [TextBlock(text: [TextRun(text: "hello")])]
            )

            XCTFail("Expected readback timeout")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .timeout)
            XCTAssertEqual(error.context["message_id"], "msg-1")
        }
    }

    func testSendMediaMessageRequiresData() async {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.sendMediaMessage(
                recipient: "11234567890",
                type: .image,
                data: []
            )
        }
    }

    func testSendMediaMessageRequiresChatStorageReadback() async throws {
        let recorder = MessageCommandRecorder()
        await recorder.setSentMediaReadback(nil)
        let service = messageService(recorder)

        do {
            _ = try await service.sendMediaMessage(
                recipient: "11234567890",
                type: .image,
                data: [0x01]
            )

            XCTFail("Expected readback timeout")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .timeout)
            XCTAssertEqual(error.context["recipient"], "11234567890")
            XCTAssertEqual(error.context["type"], "image")
        }
    }

    func testSendTextMessageRejectsDuplicateClientMessageId() async throws {
        let recorder = MessageCommandRecorder()
        let checker = TestDeduplicationChecker()
        let service = messageService(recorder, checker: checker)

        _ = try await service.sendTextMessage(
            recipient: "11234567890",
            content: [TextBlock(text: [TextRun(text: "hello")])],
            clientMessageId: "cmid-1"
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await service.sendTextMessage(
                recipient: "11234567890",
                content: [TextBlock(text: [TextRun(text: "hello")])],
                clientMessageId: "cmid-1"
            )
        }

        let sendCount = await recorder.textSendCount
        XCTAssertEqual(sendCount, 1)
    }

    func testClientMessageIdDeduplicatesAcrossMutations() async throws {
        let recorder = MessageCommandRecorder()
        let checker = TestDeduplicationChecker()
        let service = messageService(recorder, checker: checker)

        _ = try await service.sendTextMessage(
            recipient: "11234567890",
            content: [TextBlock(text: [TextRun(text: "hello")])],
            clientMessageId: "cmid-1"
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await service.sendTextMessage(
                recipient: "19876543210",
                content: [TextBlock(text: [TextRun(text: "hello")])],
                clientMessageId: "cmid-1"
            )
        }

        let sendCount = await recorder.textSendCount
        XCTAssertEqual(sendCount, 1)
    }

    func testSendTextMessageRejectsBlankClientMessageId() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.sendTextMessage(
                recipient: "11234567890",
                content: [TextBlock(text: [TextRun(text: "hello")])],
                clientMessageId: "   "
            )
        }

        let sendCount = await recorder.textSendCount
        XCTAssertEqual(sendCount, 0)
    }

    func testSendMediaMessageRejectsBlankClientMessageId() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.sendMediaMessage(
                recipient: "11234567890",
                type: .image,
                data: [0x01],
                clientMessageId: "   "
            )
        }

        let command = await recorder.lastMediaCommand
        XCTAssertNil(command)
    }

    func testSendReactionRejectsBlankClientMessageId() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.sendReaction(
                messageId: "msg-1",
                emoji: "👍",
                clientMessageId: "   "
            )
        }

        let sendCount = await recorder.reactionSendCount
        XCTAssertEqual(sendCount, 0)

        let receiptReadCount = await recorder.receiptReadCount
        XCTAssertEqual(receiptReadCount, 0)
    }

    func testSendReactionRejectsDuplicateClientMessageId() async throws {
        let recorder = MessageCommandRecorder()
        let checker = TestDeduplicationChecker()
        let service = messageService(recorder, checker: checker)

        _ = try await service.sendReaction(
            messageId: "msg-1",
            emoji: "👍",
            clientMessageId: "react-1"
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await service.sendReaction(
                messageId: "msg-1",
                emoji: "👍",
                clientMessageId: "react-1"
            )
        }

        let sendCount = await recorder.reactionSendCount
        XCTAssertEqual(sendCount, 1)
    }

    func testSendReactionRequiresChatStorageReadback() async throws {
        let recorder = MessageCommandRecorder()
        await recorder.setReactionReadback(nil)
        let service = messageService(recorder)

        do {
            _ = try await service.sendReaction(
                messageId: "msg-1",
                emoji: "👍"
            )

            XCTFail("Expected readback timeout")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .timeout)
            XCTAssertEqual(error.context["message_id"], "msg-1")
        }
    }

    func testSendReactionReturnsReactedMessageSnapshot() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        let message = try await service.sendReaction(
            messageId: "msg-1",
            emoji: "👍"
        )

        XCTAssertEqual(message.messageId, "msg-1")
        XCTAssertEqual(message.latestReaction?.emoji, "👍")
        XCTAssertEqual(message.receiptDigest, "new")
    }

    func testListRecentMessagesPageTokenBindsFilters() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)
        let before = Date(timeIntervalSince1970: 1_000.123)

        let first = try await service.listRecentMessages(
            request: RecentMessagesRequest(
                pageSize: 1,
                isFromMe: true,
                before: before
            )
        )

        XCTAssertNotNil(first.nextPageToken)

        _ = try await service.listRecentMessages(
            request: RecentMessagesRequest(
                pageSize: 1,
                pageToken: first.nextPageToken,
                isFromMe: true,
                before: before
            )
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await service.listRecentMessages(
                request: RecentMessagesRequest(
                    pageSize: 1,
                    pageToken: first.nextPageToken,
                    isFromMe: false,
                    before: before
                )
            )
        }
    }

    func testListChatMessagesRejectsRecentPageToken() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        let recent = try await service.listRecentMessages(
            request: RecentMessagesRequest(pageSize: 1)
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await service.listChatMessages(
                request: ChatMessagesRequest(
                    recipient: "11234567890",
                    pageSize: 1,
                    pageToken: recent.nextPageToken
                )
            )
        }
    }

    func testDeduplicationReleasesFailedSend() async throws {
        let recorder = MessageCommandRecorder()
        await recorder.setTextSendError(DomainError(.serviceUnavailable, "down"))

        let checker = TestDeduplicationChecker()
        let service = messageService(recorder, checker: checker)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.sendTextMessage(
                recipient: "11234567890",
                content: [TextBlock(text: [TextRun(text: "hello")])],
                clientMessageId: "cmid-1"
            )
        }

        await recorder.setTextSendError(nil)

        _ = try await service.sendTextMessage(
            recipient: "11234567890",
            content: [TextBlock(text: [TextRun(text: "hello")])],
            clientMessageId: "cmid-1"
        )

        let sendCount = await recorder.textSendCount
        XCTAssertEqual(sendCount, 1)
    }

}

private func messageService(
    _ recorder: MessageCommandRecorder,
    checker: (any DeduplicationChecking)? = nil
) -> MessageService {
    MessageService(
        sendTextMessage: recorder,
        sendMediaMessage: recorder,
        sendReaction: recorder,
        messageQuerying: recorder,
        mutationReadback: recorder,
        mutationPolicy: applicationTestMutationPolicy(checker: checker),
        eventStreaming: TestEventStream(),
        mutationReadbackDelaysNs: [0]
    )
}

extension MessageCommandRecorder {

    func setTextSendError(_ error: (any Error)?) {
        textSendError = error
    }

    func setSentTextReadback(_ readback: MessageSnapshot?) {
        sentTextReadback = readback
    }

    func setSentMediaReadback(_ readback: MessageSnapshot?) {
        sentMediaReadback = readback
    }

    func setReactionReadback(_ readback: MessageReceiptReadback?) {
        reactionReadback = readback
    }

    func setReactedMessageReadback(_ readback: MessageSnapshot?) {
        reactedMessageReadback = readback
    }

}
