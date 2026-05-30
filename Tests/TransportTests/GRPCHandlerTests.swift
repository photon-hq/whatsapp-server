import GRPCCore
import GRPCInProcessTransport
import SwiftProtobuf
import XCTest
@testable import Application
@testable import Domain
@testable import Transport

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

    func sendTextMessage(_ command: SendTextMessageCommand) async throws -> String {
        lastTextCommand = command
        return "msg-1"
    }

    func sendMediaMessage(_ command: SendMediaMessageCommand) async throws {
        lastMediaCommand = command
    }

    func sendReaction(_ command: SendReactionCommand) async throws {
        lastReactionCommand = command
    }

    func getMessage(messageId: String) async throws -> MessageSnapshot? {
        fullMessage(messageId: messageId, isFromMe: false, includeMedia: true)
    }

    func listRecentMessages(query: RecentMessagesQuery) async throws -> MessagePageSlice {
        MessagePageSlice(
            entries: [
                MessagePageEntry(
                    message: fullMessage(messageId: "recent-1", isFromMe: true, includeMedia: true),
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
        MessageSnapshot(
            messageId: "msg-1",
            recipient: query.recipient,
            chatJid: "chat@lid",
            partnerName: "Partner",
            stanzaId: "stanza-1",
            isFromMe: true,
            messageType: 0,
            messageStatus: 6,
            messageErrorStatus: 0,
            text: query.text,
            messageDate: Date(timeIntervalSince1970: 10),
            sentDate: Date(timeIntervalSince1970: 11),
            fromJid: "14155550100@s.whatsapp.net",
            toJid: "11234567890@s.whatsapp.net",
            pushName: "Sender",
            replyToMessageId: query.replyToMessageId,
            latestReaction: MessageReactionSnapshot(messageId: "msg-1", emoji: "👍"),
            receiptDigest: "digest-new"
        )
    }

    func sentMedia(
        matching query: SentMediaReadbackQuery
    ) async throws -> MessageSnapshot? {
        MessageSnapshot(
            messageId: "media-1",
            recipient: query.recipient,
            chatJid: "chat@lid",
            partnerName: "Partner",
            stanzaId: "media-stanza-1",
            isFromMe: true,
            messageType: 1,
            messageStatus: 6,
            messageErrorStatus: 0,
            text: query.caption ?? "",
            messageDate: Date(timeIntervalSince1970: 12),
            sentDate: Date(timeIntervalSince1970: 13),
            media: MessageMediaSnapshot(
                kind: .image,
                title: "photo.jpg",
                localPath: "/tmp/photo.jpg",
                mediaUrl: "https://mmg.whatsapp.net/photo.jpg",
                fileSize: 42
            )
        )
    }

    func message(
        forMessageId messageId: String
    ) async throws -> MessageSnapshot? {
        MessageSnapshot(
            messageId: messageId,
            recipient: "11234567890",
            chatJid: "chat@lid",
            partnerName: "Partner",
            stanzaId: "stanza-1",
            isFromMe: false,
            messageType: 0,
            messageStatus: 6,
            messageErrorStatus: 0,
            text: "hello",
            latestReaction: MessageReactionSnapshot(messageId: messageId, emoji: "👍"),
            receiptDigest: "old"
        )
    }

    func receipt(
        forMessageId messageId: String
    ) async throws -> MessageReceiptReadback? {
        MessageReceiptReadback(messageId: messageId, receiptDigest: "old")
    }

    func reaction(
        matching query: ReactionReadbackQuery
    ) async throws -> MessageReactionReadback? {
        MessageReactionReadback(
            receipt: MessageReceiptReadback(messageId: query.messageId, receiptDigest: "new"),
            reaction: MessageReactionSnapshot(messageId: query.messageId, emoji: query.emoji)
        )
    }

}

private actor PollCommandRecorder:
    CreatePoll,
    VotePoll,
    UnvotePoll,
    GetPoll,
    PollMutationReadback
{

    private(set) var lastCreateCommand: CreatePollCommand?
    private(set) var lastVoteCommand: VotePollCommand?
    private(set) var lastUnvotePollId: String?
    private var voteCount = 0
    private var digest = "created"

    func createPoll(_ command: CreatePollCommand) async throws -> String {
        lastCreateCommand = command
        voteCount = 0
        digest = "created"
        return "poll-1"
    }

    func votePoll(_ command: VotePollCommand) async throws {
        lastVoteCommand = command
        voteCount = 1
        digest = "voted"
    }

    func unvotePoll(pollId: String) async throws {
        lastUnvotePollId = pollId
        voteCount = 0
        digest = "unvoted"
    }

    func getPoll(pollId: String) async throws -> Poll {
        poll(pollId: pollId)
    }

    private func poll(pollId: String) -> Poll {
        Poll(
            pollId: pollId,
            question: "Lunch?",
            choices: [
                PollChoice(index: 0, text: "Sushi", voteCount: voteCount),
                PollChoice(index: 1, text: "Pizza", voteCount: 0),
            ],
            allowMultipleChoices: false,
            hideVoterNames: false
        )
    }

    func createdPoll(
        matching query: PollCreationReadbackQuery
    ) async throws -> PollMutationReadbackResult? {
        PollMutationReadbackResult(poll: poll(pollId: query.pollId), digest: digest)
    }

    func currentPollUpdate(
        pollId: String
    ) async throws -> PollMutationReadbackResult? {
        PollMutationReadbackResult(poll: poll(pollId: pollId), digest: digest)
    }

    func updatedPoll(
        matching query: PollUpdateReadbackQuery
    ) async throws -> PollMutationReadbackResult? {
        guard digest != query.previousDigest else {
            return nil
        }

        return PollMutationReadbackResult(poll: poll(pollId: query.pollId), digest: digest)
    }

}

final class GRPCHandlerTests: XCTestCase {

    func testSendTextMessageGoesThroughGeneratedGrpcContract() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_SendTextMessageRequest()
            request.recipient = "11234567890"
            request.content = [
                {
                    var block = PWApp_TextBlock()
                    block.type = .normal
                    block.text = [
                        {
                            var run = PWApp_TextRun()
                            run.text = "hello"
                            return run
                        }()
                    ]
                    return block
                }()
            ]

            let response = try await client.sendTextMessage(request)

            XCTAssertEqual(response.message.messageID, "msg-1")
        }

        let command = await recorder.lastTextCommand
        XCTAssertEqual(command?.recipient, "11234567890")
        XCTAssertEqual(command?.text, "hello")
    }

    func testMessageWriteAndReadResponsesExposeCompleteMessageShape() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var textRequest = PWApp_SendTextMessageRequest()
            textRequest.recipient = "11234567890"
            textRequest.content = [textBlock("hello")]
            textRequest.replyTo = "parent-1"
            let sentText = try await client.sendTextMessage(textRequest)

            XCTAssertEqual(sentText.message.messageID, "msg-1")
            XCTAssertEqual(sentText.message.recipient, "11234567890")
            XCTAssertEqual(sentText.message.chatJid, "chat@lid")
            XCTAssertEqual(sentText.message.partnerName, "Partner")
            XCTAssertEqual(sentText.message.stanzaID, "stanza-1")
            XCTAssertTrue(sentText.message.isFromMe)
            XCTAssertEqual(sentText.message.messageType, 0)
            XCTAssertEqual(sentText.message.messageStatus, 6)
            XCTAssertEqual(sentText.message.messageErrorStatus, 0)
            XCTAssertEqual(sentText.message.text, "hello")
            XCTAssertEqual(sentText.message.replyToMessageID, "parent-1")
            XCTAssertEqual(sentText.message.latestReaction.emoji, "👍")
            XCTAssertEqual(sentText.message.receiptDigest, "digest-new")

            var mediaRequest = PWApp_SendMediaMessageRequest()
            mediaRequest.recipient = "11234567890"
            mediaRequest.media.kind = .image
            mediaRequest.media.data = Data([0xFF, 0xD8, 0xFF])
            mediaRequest.media.caption = "photo"
            let sentMedia = try await client.sendMediaMessage(mediaRequest)

            XCTAssertEqual(sentMedia.message.messageID, "media-1")
            XCTAssertEqual(sentMedia.message.media.kind, .image)
            XCTAssertEqual(sentMedia.message.media.title, "photo.jpg")
            XCTAssertEqual(sentMedia.message.media.localPath, "/tmp/photo.jpg")
            XCTAssertEqual(sentMedia.message.media.mediaURL, "https://mmg.whatsapp.net/photo.jpg")
            XCTAssertEqual(sentMedia.message.media.fileSize, 42)

            var reactionRequest = PWApp_SendReactionRequest()
            reactionRequest.messageID = "msg-1"
            reactionRequest.emoji = "❤️"
            let reacted = try await client.sendReaction(reactionRequest)

            XCTAssertEqual(reacted.message.messageID, "msg-1")
            XCTAssertEqual(reacted.message.latestReaction.emoji, "❤️")
            XCTAssertEqual(reacted.message.receiptDigest, "new")

            var getRequest = PWApp_GetMessageRequest()
            getRequest.messageID = "msg-1"
            let found = try await client.getMessage(getRequest)

            XCTAssertEqual(found.message.messageID, "msg-1")
            XCTAssertEqual(found.message.chatJid, "chat@lid")
            XCTAssertEqual(found.message.media.kind, .image)
        }
    }

    func testSendReactionReturnsMessage() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_SendReactionRequest()
            request.messageID = "msg-1"
            request.emoji = "👍"

            let response = try await client.sendReaction(request)

            XCTAssertEqual(response.message.messageID, "msg-1")
            XCTAssertEqual(response.message.latestReaction.emoji, "👍")
            XCTAssertEqual(response.message.receiptDigest, "new")
        }

        let command = await recorder.lastReactionCommand
        XCTAssertEqual(command?.messageId, "msg-1")
        XCTAssertEqual(command?.emoji, "👍")
    }

    func testSendMediaMessageGoesThroughGeneratedGrpcContract() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_SendMediaMessageRequest()
            request.recipient = "11234567890"
            request.media.kind = .image
            request.media.data = Data([0xFF, 0xD8, 0xFF])
            request.media.caption = "photo"
            request.media.accessibilityText = "demo photo"

            let response = try await client.sendMediaMessage(request)

            XCTAssertEqual(response.message.messageID, "media-1")
        }

        let command = await recorder.lastMediaCommand
        XCTAssertEqual(command?.recipient, "11234567890")
        XCTAssertEqual(command?.type, .image)
        XCTAssertEqual(command?.data, [0xFF, 0xD8, 0xFF])
        XCTAssertEqual(command?.caption, "photo")
        XCTAssertEqual(command?.accessibilityText, "demo photo")
    }

    func testSendVideoMessageGoesThroughGeneratedGrpcContract() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_SendMediaMessageRequest()
            request.recipient = "11234567890"
            request.media.kind = .video
            request.media.data = Data("0000ftypmp42".utf8)

            let response = try await client.sendMediaMessage(request)

            XCTAssertEqual(response.message.messageID, "media-1")
        }

        let command = await recorder.lastMediaCommand
        XCTAssertEqual(command?.type, .video)
    }

    func testGetMessageGoesThroughGeneratedGrpcContract() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_GetMessageRequest()
            request.messageID = "msg-1"

            let response = try await client.getMessage(request)

            XCTAssertEqual(response.message.messageID, "msg-1")
        }
    }

    func testListRecentMessagesReturnsFullMessagePage() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_ListRecentMessagesRequest()
            request.pageSize = 1
            request.isFromMe = true

            let response = try await client.listRecentMessages(request)

            XCTAssertEqual(response.messages.first?.messageID, "recent-1")
            XCTAssertEqual(response.messages.first?.recipient, "11234567890")
            XCTAssertEqual(response.messages.first?.media.kind, .image)
            XCTAssertFalse(response.nextPageToken.isEmpty)
        }
    }

    func testListChatMessagesMapsRecipientAndReturnsFullMessagePage() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_ListChatMessagesRequest()
            request.recipient = "11234567890"
            request.pageSize = 1

            let response = try await client.listChatMessages(request)

            XCTAssertEqual(response.messages.first?.messageID, "recent-1")
            XCTAssertFalse(response.nextPageToken.isEmpty)
        }
    }

    func testMessageRpcInputBoundaryErrorsExposePreciseFields() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            await assertRPCInvalidArgument(field: "recipient") {
                var request = PWApp_SendTextMessageRequest()
                request.recipient = "+11234567890"
                request.content = [textBlock("hello")]
                _ = try await client.sendTextMessage(request)
            }

            await assertRPCInvalidArgument(field: "content") {
                var request = PWApp_SendTextMessageRequest()
                request.recipient = "11234567890"
                _ = try await client.sendTextMessage(request)
            }

            await assertRPCInvalidArgument(field: "client_message_id") {
                var request = PWApp_SendTextMessageRequest()
                request.recipient = "11234567890"
                request.content = [textBlock("hello")]
                request.clientMessageID = "   "
                _ = try await client.sendTextMessage(request)
            }

            await assertRPCInvalidArgument(field: "page_size") {
                var request = PWApp_ListRecentMessagesRequest()
                request.pageSize = 101
                _ = try await client.listRecentMessages(request)
            }

            await assertRPCInvalidArgument(field: "after") {
                var request = PWApp_ListRecentMessagesRequest()
                request.before = Google_Protobuf_Timestamp(date: Date(timeIntervalSince1970: 10))
                request.after = Google_Protobuf_Timestamp(date: Date(timeIntervalSince1970: 10))
                _ = try await client.listRecentMessages(request)
            }
        }
    }

    func testSendMediaMessageRejectsMissingMedia() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_SendMediaMessageRequest()
            request.recipient = "11234567890"

            do {
                _ = try await client.sendMediaMessage(request)
                XCTFail("Expected RPCError")
            } catch let error as RPCError {
                XCTAssertEqual(error.code, .invalidArgument)
                XCTAssertEqual(
                    firstString(error.metadata, "error-context-field"),
                    "media"
                )
            }
        }
    }

    func testSendMediaMessageRejectsUnknownKind() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_SendMediaMessageRequest()
            request.recipient = "11234567890"
            request.media.kind = .UNRECOGNIZED(99)
            request.media.data = Data([0xFF, 0xD8, 0xFF])

            do {
                _ = try await client.sendMediaMessage(request)
                XCTFail("Expected RPCError")
            } catch let error as RPCError {
                XCTAssertEqual(error.code, .invalidArgument)
                XCTAssertEqual(
                    firstString(error.metadata, "error-context-field"),
                    "media.kind"
                )
            }
        }
    }

    func testSendTextRejectsUnknownStyle() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_SendTextMessageRequest()
            request.recipient = "11234567890"
            request.content = [
                {
                    var block = PWApp_TextBlock()
                    block.type = .normal
                    block.text = [
                        {
                            var run = PWApp_TextRun()
                            run.text = "hello"
                            run.styles = [.UNRECOGNIZED(99)]
                            return run
                        }()
                    ]
                    return block
                }()
            ]

            do {
                _ = try await client.sendTextMessage(request)
                XCTFail("Expected RPCError")
            } catch let error as RPCError {
                XCTAssertEqual(error.code, .invalidArgument)
                XCTAssertEqual(
                    firstString(error.metadata, "error-context-field"),
                    "content[0].text[0].styles[0]"
                )
            }
        }
    }

    func testSendTextRejectsUnknownBlockTypeWithPreciseField() async throws {
        let recorder = MessageCommandRecorder()
        let service = messageService(recorder)

        try await withMessageClient(service: service) { client in
            var request = PWApp_SendTextMessageRequest()
            request.recipient = "11234567890"
            request.content = [
                {
                    var block = PWApp_TextBlock()
                    block.type = .UNRECOGNIZED(99)
                    block.text = [
                        {
                            var run = PWApp_TextRun()
                            run.text = "hello"
                            return run
                        }()
                    ]
                    return block
                }()
            ]

            do {
                _ = try await client.sendTextMessage(request)
                XCTFail("Expected RPCError")
            } catch let error as RPCError {
                XCTAssertEqual(error.code, .invalidArgument)
                XCTAssertEqual(
                    firstString(error.metadata, "error-context-field"),
                    "content[0].type"
                )
            }
        }
    }

    func testCreatePollGoesThroughGeneratedGrpcContract() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        try await withPollClient(service: service) { client in
            var request = PWApp_CreatePollRequest()
            request.recipient = "11234567890"
            request.question = "Lunch?"
            request.choices = ["Sushi", "Pizza"]

            let response = try await client.createPoll(request)

            XCTAssertEqual(response.poll.pollID, "poll-1")
            XCTAssertEqual(response.poll.question, "Lunch?")
            XCTAssertEqual(response.poll.choices.first?.text, "Sushi")
        }

        let command = await recorder.lastCreateCommand
        XCTAssertEqual(command?.allowMultipleChoices, false)
    }

    func testPollRpcInputBoundaryErrorsExposePreciseFields() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        try await withPollClient(service: service) { client in
            await assertRPCInvalidArgument(field: "recipient") {
                var request = PWApp_CreatePollRequest()
                request.recipient = "+11234567890"
                request.question = "Lunch?"
                request.choices = ["Sushi", "Pizza"]
                _ = try await client.createPoll(request)
            }

            await assertRPCInvalidArgument(field: "question") {
                var request = PWApp_CreatePollRequest()
                request.recipient = "11234567890"
                request.question = "   "
                request.choices = ["Sushi", "Pizza"]
                _ = try await client.createPoll(request)
            }

            await assertRPCInvalidArgument(field: "choices") {
                var request = PWApp_CreatePollRequest()
                request.recipient = "11234567890"
                request.question = "Lunch?"
                request.choices = ["Sushi"]
                _ = try await client.createPoll(request)
            }

            await assertRPCInvalidArgument(field: "choice_indexes") {
                var request = PWApp_VotePollRequest()
                request.pollID = "poll-1"
                _ = try await client.votePoll(request)
            }

            await assertRPCInvalidArgument(field: "choice_indexes") {
                var request = PWApp_VotePollRequest()
                request.pollID = "poll-1"
                request.choiceIndexes = [-1]
                _ = try await client.votePoll(request)
            }

            await assertRPCInvalidArgument(field: "poll_id") {
                var request = PWApp_UnvotePollRequest()
                request.pollID = "   "
                _ = try await client.unvotePoll(request)
            }
        }
    }

    func testVotePollMapsIndexesAndPollId() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        try await withPollClient(service: service) { client in
            var request = PWApp_VotePollRequest()
            request.pollID = "poll-1"
            request.choiceIndexes = [0, 1]

            let response = try await client.votePoll(request)

            XCTAssertEqual(response.poll.pollID, "poll-1")
            XCTAssertEqual(response.poll.question, "Lunch?")
            XCTAssertEqual(response.poll.choices.first?.text, "Sushi")
            XCTAssertEqual(response.poll.choices.first?.voteCount, 1)
        }

        let command = await recorder.lastVoteCommand
        XCTAssertEqual(command?.pollId, "poll-1")
        XCTAssertEqual(command?.choiceIndexes, [0, 1])
    }

    func testUnvotePollReturnsPoll() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        try await withPollClient(service: service) { client in
            var request = PWApp_UnvotePollRequest()
            request.pollID = "poll-1"

            let response = try await client.unvotePoll(request)

            XCTAssertEqual(response.poll.pollID, "poll-1")
            XCTAssertEqual(response.poll.question, "Lunch?")
        }

        let pollId = await recorder.lastUnvotePollId
        XCTAssertEqual(pollId, "poll-1")
    }

    func testSubscribePollEventsStreamsPollChanges() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(
            recorder,
            eventStreaming: TestEventStream(subscriptionEvents: [
                DomainEventEnvelope(
                    sequence: 7,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .poll(.changed(PollChangeEvent(
                        recipient: "15551619824",
                        pollId: "poll-1",
                        sourceRowId: 10,
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
                )
            ])
        )

        try await withPollClient(service: service) { client in
            let response = try await client.subscribePollEvents(
                PWApp_SubscribePollEventsRequest()
            ) { stream in
                var iterator = stream.messages.makeAsyncIterator()
                _ = try await iterator.next()
                return try await iterator.next()
            }

            XCTAssertEqual(response?.sequence, 7)
            XCTAssertEqual(response?.pollChanged.pollID, "poll-1")
            XCTAssertEqual(response?.pollChanged.created.question, "Lunch?")
        }
    }

    func testSubscribeMessageEventsStreamsTextChanges() async throws {
        let service = messageService(
            MessageCommandRecorder(),
            eventStreaming: TestEventStream(subscriptionEvents: [
                DomainEventEnvelope(
                    sequence: 6,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .message(.changed(MessageChangeEvent(
                        recipient: "15551619824",
                        sourceRowId: 9,
                        occurredAt: Date(timeIntervalSince1970: 2),
                        isFromMe: true,
                        change: .text(MessageText(
                            messageId: "msg-1",
                            text: "hello",
                            replyToMessageId: "parent-1"
                        ))
                    )))
                )
            ])
        )

        try await withMessageClient(service: service) { client in
            let response = try await client.subscribeMessageEvents(
                PWApp_SubscribeMessageEventsRequest()
            ) { stream in
                var iterator = stream.messages.makeAsyncIterator()
                _ = try await iterator.next()
                return try await iterator.next()
            }

            XCTAssertEqual(response?.sequence, 6)
            XCTAssertEqual(response?.messageChanged.recipient, "15551619824")
            XCTAssertEqual(response?.messageChanged.text.messageID, "msg-1")
            XCTAssertEqual(response?.messageChanged.text.text, "hello")
            XCTAssertEqual(response?.messageChanged.text.replyToMessageID, "parent-1")
        }
    }

    func testSubscribeMessageEventsStreamsAttachmentChanges() async throws {
        let service = messageService(
            MessageCommandRecorder(),
            eventStreaming: TestEventStream(subscriptionEvents: [
                DomainEventEnvelope(
                    sequence: 7,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .message(.changed(MessageChangeEvent(
                        recipient: "15551619824",
                        sourceRowId: 10,
                        occurredAt: Date(timeIntervalSince1970: 2),
                        isFromMe: false,
                        change: .attachment(MessageAttachment(
                            messageId: "photo-1",
                            kind: .image,
                            caption: "photo",
                            localPath: "/tmp/photo.jpg",
                            fileSize: 42,
                            title: "photo.jpg",
                            replyToMessageId: nil
                        ))
                    )))
                )
            ])
        )

        try await withMessageClient(service: service) { client in
            let response = try await client.subscribeMessageEvents(
                PWApp_SubscribeMessageEventsRequest()
            ) { stream in
                var iterator = stream.messages.makeAsyncIterator()
                _ = try await iterator.next()
                return try await iterator.next()
            }

            XCTAssertEqual(response?.sequence, 7)
            XCTAssertEqual(response?.messageChanged.attachment.messageID, "photo-1")
            XCTAssertEqual(response?.messageChanged.attachment.kind, .image)
            XCTAssertEqual(response?.messageChanged.attachment.caption, "photo")
            XCTAssertEqual(response?.messageChanged.attachment.localPath, "/tmp/photo.jpg")
            XCTAssertEqual(response?.messageChanged.attachment.fileSize, 42)
        }
    }

    func testSubscribeMessageEventsStreamsReactionAndReceiptChanges() async throws {
        let service = messageService(
            MessageCommandRecorder(),
            eventStreaming: TestEventStream(subscriptionEvents: [
                DomainEventEnvelope(
                    sequence: 8,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .message(.changed(MessageChangeEvent(
                        recipient: "15551619824",
                        sourceRowId: 10,
                        occurredAt: Date(timeIntervalSince1970: 2),
                        isFromMe: false,
                        change: .reaction(MessageReaction(
                            messageId: "message-1",
                            emoji: "👍",
                            actorJid: "12345@lid",
                            reactionId: "3B50485D7776329E4293"
                        ))
                    )))
                ),
                DomainEventEnvelope(
                    sequence: 9,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .message(.changed(MessageChangeEvent(
                        recipient: "15551619824",
                        sourceRowId: 11,
                        occurredAt: Date(timeIntervalSince1970: 3),
                        isFromMe: true,
                        change: .receipt(MessageReceiptUpdate(
                            messageId: "message-2",
                            receiptDigest: "digest-1"
                        ))
                    )))
                ),
            ])
        )

        try await withMessageClient(service: service) { client in
            let responses = try await client.subscribeMessageEvents(
                PWApp_SubscribeMessageEventsRequest()
            ) { stream in
                var iterator = stream.messages.makeAsyncIterator()
                _ = try await iterator.next()
                return [
                    try await iterator.next(),
                    try await iterator.next(),
                ]
            }

            XCTAssertEqual(responses[0]?.sequence, 8)
            XCTAssertEqual(responses[0]?.messageChanged.reaction.messageID, "message-1")
            XCTAssertEqual(responses[0]?.messageChanged.reaction.emoji, "👍")
            XCTAssertEqual(responses[0]?.messageChanged.reaction.actorJid, "12345@lid")
            XCTAssertEqual(responses[0]?.messageChanged.reaction.reactionID, "3B50485D7776329E4293")
            XCTAssertEqual(responses[1]?.sequence, 9)
            XCTAssertEqual(responses[1]?.messageChanged.receipt.messageID, "message-2")
            XCTAssertEqual(responses[1]?.messageChanged.receipt.receiptDigest, "digest-1")
        }
    }

    func testSubscribePollEventsStreamsVoteChanges() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(
            recorder,
            eventStreaming: TestEventStream(subscriptionEvents: [
                DomainEventEnvelope(
                    sequence: 8,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .poll(.changed(PollChangeEvent(
                        recipient: "15551619824",
                        pollId: "poll-1",
                        sourceRowId: 10,
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
                )
            ])
        )

        try await withPollClient(service: service) { client in
            let response = try await client.subscribePollEvents(
                PWApp_SubscribePollEventsRequest()
            ) { stream in
                var iterator = stream.messages.makeAsyncIterator()
                _ = try await iterator.next()
                return try await iterator.next()
            }

            XCTAssertEqual(response?.sequence, 8)
            XCTAssertEqual(response?.pollChanged.voteChanged.pollID, "poll-1")
            XCTAssertEqual(response?.pollChanged.voteChanged.choices.first?.voteCount, 1)
        }
    }

    func testCatchUpEventsStreamsOnlyMessageAndPollChanges() async throws {
        let eventStreaming = TestEventStream(
            latestSequence: 13,
            replayEvents: [
                DomainEventEnvelope(
                    sequence: 6,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .message(.changed(MessageChangeEvent(
                        recipient: "15551619824",
                        sourceRowId: 9,
                        occurredAt: Date(timeIntervalSince1970: 2),
                        isFromMe: true,
                        change: .text(MessageText(messageId: "msg-1", text: "hello"))
                    )))
                ),
                DomainEventEnvelope(
                    sequence: 7,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .message(.changed(MessageChangeEvent(
                        recipient: "15551619824",
                        sourceRowId: 10,
                        occurredAt: Date(timeIntervalSince1970: 2),
                        isFromMe: false,
                        change: .attachment(MessageAttachment(
                            messageId: "photo-1",
                            kind: .image,
                            caption: "photo",
                            localPath: "/tmp/photo.jpg",
                            fileSize: 42
                        ))
                    )))
                ),
                DomainEventEnvelope(
                    sequence: 8,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .message(.changed(MessageChangeEvent(
                        recipient: "15551619824",
                        sourceRowId: 11,
                        occurredAt: Date(timeIntervalSince1970: 2),
                        isFromMe: false,
                        change: .reaction(MessageReaction(
                            messageId: "msg-1",
                            emoji: "👍",
                            actorJid: "12345@lid",
                            reactionId: "3B50485D7776329E4293"
                        ))
                    )))
                ),
                DomainEventEnvelope(
                    sequence: 9,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .poll(.changed(PollChangeEvent(
                        recipient: "15551619824",
                        pollId: "poll-1",
                        sourceRowId: 10,
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
                ),
                DomainEventEnvelope(
                    sequence: 10,
                    recordedAt: Date(timeIntervalSince1970: 1),
                    event: .poll(.changed(PollChangeEvent(
                        recipient: "15551619824",
                        pollId: "poll-1",
                        sourceRowId: 10,
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
                ),
            ]
        )
        let service = EventService(
            eventStreaming: eventStreaming,
            messageProjector: MessageEventProjector()
        )

        try await withEventClient(service: service) { client in
            let responses = try await client.catchUpEvents(
                {
                    var request = PWApp_CatchUpEventsRequest()
                    request.afterSequence = 5
                    return request
                }()
            ) { stream in
                var collected: [PWApp_CatchUpEventsResponse] = []

                for try await response in stream.messages {
                    collected.append(response)

                    if response.payload != nil,
                       case .complete = response.payload
                    {
                        break
                    }
                }

                return collected
            }

            XCTAssertEqual(responses.count, 7)
            XCTAssertFalse(responses[0].hasSequence)
            XCTAssertEqual(responses[1].sequence, 6)
            XCTAssertEqual(responses[1].messageChanged.text.text, "hello")
            XCTAssertEqual(responses[2].sequence, 7)
            XCTAssertEqual(responses[2].messageChanged.attachment.messageID, "photo-1")
            XCTAssertEqual(responses[3].sequence, 8)
            XCTAssertEqual(responses[3].messageChanged.reaction.emoji, "👍")
            XCTAssertEqual(responses[4].sequence, 9)
            XCTAssertEqual(responses[4].pollChanged.pollID, "poll-1")
            XCTAssertEqual(responses[4].pollChanged.created.question, "Lunch?")
            XCTAssertEqual(responses[5].sequence, 10)
            XCTAssertEqual(responses[5].pollChanged.voteChanged.choices.first?.voteCount, 1)
            XCTAssertEqual(responses[6].complete.headSequence, 13)
        }
    }

    private func withMessageClient(
        service: MessageService,
        _ body: (PWApp_MessageService.Client<InProcessTransport.Client>) async throws -> Void
    ) async throws {
        let inProcess = InProcessTransport()
        try await withGRPCServer(
            transport: inProcess.server,
            services: [MessageServiceHandler(messages: service)]
        ) { _ in
            try await withGRPCClient(transport: inProcess.client) { client in
                try await body(PWApp_MessageService.Client(wrapping: client))
            }
        }
    }

    private func withPollClient(
        service: PollService,
        _ body: (PWApp_PollService.Client<InProcessTransport.Client>) async throws -> Void
    ) async throws {
        let inProcess = InProcessTransport()
        try await withGRPCServer(
            transport: inProcess.server,
            services: [PollServiceHandler(polls: service)]
        ) { _ in
            try await withGRPCClient(transport: inProcess.client) { client in
                try await body(PWApp_PollService.Client(wrapping: client))
            }
        }
    }

    private func withEventClient(
        service: EventService,
        _ body: (PWApp_EventService.Client<InProcessTransport.Client>) async throws -> Void
    ) async throws {
        let inProcess = InProcessTransport()
        try await withGRPCServer(
            transport: inProcess.server,
            services: [EventServiceHandler(events: service)]
        ) { _ in
            try await withGRPCClient(transport: inProcess.client) { client in
                try await body(PWApp_EventService.Client(wrapping: client))
            }
        }
    }

    private func firstString(
        _ metadata: Metadata,
        _ key: String
    ) -> String? {
        Array(metadata[stringValues: key]).first
    }

}

private func textBlock(_ text: String) -> PWApp_TextBlock {
    var block = PWApp_TextBlock()
    block.type = .normal
    var run = PWApp_TextRun()
    run.text = text
    block.text = [run]
    return block
}

private func fullMessage(
    messageId: String,
    isFromMe: Bool,
    includeMedia: Bool = false
) -> MessageSnapshot {
    MessageSnapshot(
        messageId: messageId,
        recipient: "11234567890",
        chatJid: "chat@lid",
        partnerName: "Partner",
        stanzaId: "stanza-1",
        isFromMe: isFromMe,
        messageType: includeMedia ? 1 : 0,
        messageStatus: 6,
        messageErrorStatus: 0,
        text: includeMedia ? "photo" : "hello",
        messageDate: Date(timeIntervalSince1970: 10),
        sentDate: Date(timeIntervalSince1970: 11),
        fromJid: "14155550100@s.whatsapp.net",
        toJid: "11234567890@s.whatsapp.net",
        pushName: "Sender",
        replyToMessageId: "parent-1",
        media: includeMedia
            ? MessageMediaSnapshot(
                kind: .image,
                title: "photo.jpg",
                localPath: "/tmp/photo.jpg",
                mediaUrl: "https://mmg.whatsapp.net/photo.jpg",
                fileSize: 42
            )
            : nil,
        latestReaction: MessageReactionSnapshot(messageId: messageId, emoji: "👍"),
        receiptDigest: "digest-new"
    )
}

private func assertRPCInvalidArgument(
    field: String,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> Void
) async {
    do {
        try await operation()
        XCTFail("Expected invalidArgument", file: file, line: line)
    } catch let error as RPCError {
        XCTAssertEqual(error.code, .invalidArgument, file: file, line: line)
        XCTAssertEqual(
            Array(error.metadata[stringValues: "error-context-field"]).first,
            field,
            file: file,
            line: line
        )
    } catch {
        XCTFail("Expected RPCError, got \(error)", file: file, line: line)
    }
}

private func messageService(
    _ recorder: MessageCommandRecorder,
    eventStreaming: any DomainEventStreaming = TestEventStream()
) -> MessageService {
    MessageService(
        sendTextMessage: recorder,
        sendMediaMessage: recorder,
        sendReaction: recorder,
        messageQuerying: recorder,
        mutationReadback: recorder,
        mutationPolicy: NoopMutationPolicy(),
        eventStreaming: eventStreaming,
        mutationReadbackDelaysNs: [0]
    )
}


private func pollService(
    _ recorder: PollCommandRecorder,
    eventStreaming: any DomainEventStreaming = TestEventStream()
) -> PollService {
    PollService(
        createPoll: recorder,
        votePoll: recorder,
        unvotePoll: recorder,
        getPoll: recorder,
        mutationReadback: recorder,
        mutationPolicy: NoopMutationPolicy(),
        eventStreaming: eventStreaming,
        mutationReadbackDelaysNs: [0]
    )
}

private struct NoopMutationPolicy: MutationPolicy {

    func execute<T: Sendable>(
        clientMessageId: String?,
        _ body: @Sendable () async throws -> T
    ) async throws -> T {
        try await body()
    }
}

private actor TestEventStream: DomainEventStreaming {

    private let subscriptionEvents: [DomainEventEnvelope]
    private let replayEvents: [DomainEventEnvelope]
    private let latestSequenceValue: UInt64

    init(
        latestSequence: UInt64 = 0,
        subscriptionEvents: [DomainEventEnvelope] = [],
        replayEvents: [DomainEventEnvelope] = []
    ) {
        self.latestSequenceValue = latestSequence
        self.subscriptionEvents = subscriptionEvents
        self.replayEvents = replayEvents
    }

    func publish(_ event: DomainEvent) async throws {}

    func publish(_ events: [DomainEvent]) async throws {}

    func publish(
        _ events: [DomainEvent],
        cursor: NamedCursor
    ) async throws {}

    func latestSequence() async throws -> UInt64 {
        latestSequenceValue
    }

    func subscribe() async throws -> EventSubscription<DomainEventEnvelope> {
        let events = subscriptionEvents

        return EventSubscription(
            AsyncThrowingStream { continuation in
                for event in events {
                    continuation.yield(event)
                }

                continuation.finish()
            }
        )
    }

    func replay(
        afterSequence: UInt64,
        throughSequence: UInt64
    ) async throws -> EventSubscription<DomainEventEnvelope> {
        let events = replayEvents.filter {
            $0.sequence > afterSequence && $0.sequence <= throughSequence
        }

        return EventSubscription(
            AsyncThrowingStream { continuation in
                for event in events {
                    continuation.yield(event)
                }

                continuation.finish()
            }
        )
    }

    func resume(afterSequence: UInt64) async throws -> EventSubscription<DomainEventEnvelope> {
        EventSubscription(
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        )
    }

    func loadCursor(name: String) async throws -> String? {
        nil
    }

    func saveCursor(_ cursor: NamedCursor) async throws {}

}
