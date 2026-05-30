import XCTest
@testable import Domain
@testable import Infrastructure

final class ChatStorageEventObserverTests: XCTestCase {

    func testAttachmentRowDoesNotBecomeText() {
        let record = eventRecord(
            text: "",
            mediaLocalPath: nil,
            mediaFileSize: 128,
            mediaTitle: "image"
        )

        XCTAssertNil(record.messageText)
        XCTAssertEqual(record.attachment?.kind, .document)
        XCTAssertEqual(record.attachment?.fileSize, 128)
    }

    func testAttachmentTakesPrecedenceOverCaptionText() {
        let record = eventRecord(
            text: "caption",
            mediaLocalPath: "/tmp/photo.jpg"
        )

        XCTAssertNil(record.messageText)
        XCTAssertEqual(record.attachment?.kind, .image)
        XCTAssertEqual(record.attachment?.caption, "caption")
    }

    func testMediaPathTakesPrecedenceOverPlaceholderLocationCoordinates() {
        let record = eventRecord(
            text: nil,
            mediaLocalPath: "/tmp/photo.jpg",
            mediaFileSize: 440,
            mediaTitle: "photo caption",
            mediaVCardName: "internal-media-token",
            mediaLatitude: 1,
            mediaLongitude: 1
        )

        XCTAssertEqual(record.attachment?.kind, .image)
        XCTAssertEqual(record.attachment?.caption, "photo caption")
        XCTAssertNil(record.attachment?.title)
    }

    func testVideoMessageTypeStaysVideoWhileDownloadPathIsPending() {
        let record = eventRecord(
            text: nil,
            mediaFileSize: 440,
            mediaTitle: "video caption",
            mediaVCardName: "internal-media-token",
            messageType: 2
        )

        XCTAssertEqual(record.attachment?.kind, .video)
        XCTAssertEqual(record.attachment?.caption, "video caption")
        XCTAssertNil(record.attachment?.title)
    }

    func testAttachmentMetadataWithoutPathStillDoesNotBecomeText() {
        let record = eventRecord(
            text: "caption",
            mediaFileSize: 128
        )

        XCTAssertNil(record.messageText)
        XCTAssertEqual(record.attachment?.caption, "caption")
        XCTAssertEqual(record.attachment?.kind, .document)
    }

    func testEmptyMediaDefaultsDoNotTurnTextIntoLocationAttachment() {
        let record = eventRecord(
            text: "hello",
            mediaFileSize: 0,
            mediaLatitude: 0,
            mediaLongitude: 0
        )

        XCTAssertNil(record.attachment)
        XCTAssertEqual(record.messageText?.text, "hello")
    }

    func testReplyMetadataDoesNotTurnTextIntoAttachment() {
        let record = eventRecord(
            text: "reply text",
            mediaFileSize: 0,
            mediaMetadata: Data("parent-stanza quoted text".utf8)
        )

        XCTAssertNil(record.attachment)
        XCTAssertEqual(record.messageText?.text, "reply text")
    }

    func testStoredMessageDateUsesAppleReferenceDate() {
        let record = eventRecord(
            text: "hello",
            messageDate: 800_367_109.238634
        )

        XCTAssertEqual(
            Int(record.occurredAt.timeIntervalSince1970),
            1_778_674_309
        )
    }

    func testGroupRecipientUsesGroupJidEvenWhenDisplayNameContainsDigits() {
        let record = eventRecord(
            contactJid: "120363000000000000@g.us",
            partnerName: "Team 123",
            text: "hello"
        )

        XCTAssertEqual(record.recipient, "120363000000000000@g.us")
    }

    func testLidRecipientFallsBackToPartnerPhoneNumber() {
        let record = eventRecord(
            contactJid: "48761485131844@lid",
            partnerName: "+1 (908) 430-1481",
            text: "hello"
        )

        XCTAssertEqual(record.recipient, "19084301481")
    }

    func testPollVoteCountChangeEmitsVoteChanged() {
        let old = pollSnapshot(voteCounts: [0, 0])
        let new = pollSnapshot(voteCounts: [1, 0])

        let events = ChatStorageEventObserver.pollEvents(
            from: ["poll-1": old],
            to: ["poll-1": new],
            occurredAt: Date(timeIntervalSince1970: 10)
        )

        XCTAssertEqual(events.count, 1)

        guard case .poll(.changed(let event)) = events.first,
              case .voteChanged(let poll) = event.change
        else {
            XCTFail("Expected poll voteChanged event")
            return
        }

        XCTAssertEqual(event.pollId, "poll-1")
        XCTAssertEqual(poll.choices.map(\.voteCount), [1, 0])
    }

    func testPollChoiceTextChangeEmitsChoicesChanged() {
        let old = pollSnapshot(optionTexts: ["A", "B"], voteCounts: [0, 0])
        let new = pollSnapshot(optionTexts: ["A", "B", "C"], voteCounts: [0, 0, 0])

        let events = ChatStorageEventObserver.pollEvents(
            from: ["poll-1": old],
            to: ["poll-1": new],
            occurredAt: Date(timeIntervalSince1970: 10)
        )

        guard case .poll(.changed(let event)) = events.first,
              case .choicesChanged(let poll) = event.change
        else {
            XCTFail("Expected poll choicesChanged event")
            return
        }

        XCTAssertEqual(poll.choices.map(\.text), ["A", "B", "C"])
    }

    func testInboundPollMetadataParsesPollSnapshot() {
        let metadata = Data(hexString: """
        4aa7019a024a0a240a0a1e135c3b033d706a71f810b9cb95d006420acbe129d72fe253bd873d48b6c495d00610021a209cc3e2d6e3513003a595a962f9886197626bbcf57d024cd61c606299f405c100ba075712296d61747269782072656d6f746520706f6c6c2032303236303531342d3231313931392d646266696c6c1a0a0a0872656d6f746520411a0a0a0872656d6f746520421a0a0a0872656d6f7465204320003001380058015002a204209cc3e2d6e3513003a595a962f9886197626bbcf57d024cd61c606299f405c100ea08c803080312c303f8101318fc0457616e671aff051778764788fc03737473ff08177876478828051608fb0a3b6446397e6495568e7a06f70101ff074876148513184404eda1fc0973656e6465725f706efaff8619084301481f03f803f8061d5145044dfcf3330a2105c333774d38ca4b94d1c110a1a834577ffff0c434f1719aa5f6d395333aeca4071000180122c001553255365164ab45ee3073583b5d1894951e1cdad06755ea355e589aa001fd411c22c90188e9c2e3572d7a1381c13d2bda0260bc8d00b7f80e6b631dff2e4aa91f08468fed7c8a7521ae25009be0fb188cb37251325ccbbeeb10a690b6faa8fcf483e459e11ebbdbf335d6f4b83f4cd32e2016009068847e9efd0106ffd10915a6153f6d7e08b1e21fe66f52340d2deb5c62ac7cc74b7b7471b46e44b4346c6bcb89a5192b360223ec495b253cc01733c2aa96afeacc394d11a4893a1ad4cdc88ae9d3bb90b1294bf802fc097265706f7274696e67f802f802fc0d7265706f7274696e675f746167fc14011390de5749cd753529cdba129e84725bce66f7f804fc0f7265706f7274696e675f746f6b656e5145fc1033f1cdf05fb3316d26b41b365f2a4a56f805ed7dfc0b636f6e74656e747479706538ecf73c
        """)

        let record = eventRecord(
            text: nil,
            isFromMe: false,
            messageType: 13,
            mediaMetadata: metadata
        )

        let poll = record.poll

        XCTAssertEqual(poll?.pollId, "15551234567@s.whatsapp.net_stanza-1_0_0")
        XCTAssertEqual(poll?.question, "matrix remote poll 20260514-211919-dbfill")
        XCTAssertEqual(poll?.choices.map(\.text), ["remote A", "remote B", "remote C"])
        XCTAssertEqual(poll?.choices.map(\.voteCount), [0, 0, 0])
        XCTAssertEqual(poll?.allowMultipleChoices, true)
        XCTAssertEqual(poll?.hideVoterNames, false)
        XCTAssertNil(record.messageText)
        XCTAssertNil(record.attachment)
        XCTAssertTrue(record.isPollMessage)
    }

    func testPollReceiptInfoParsesCurrentVoteState() {
        let receiptInfo = Data(hexString: """
        12160A088C487614851318444A04080010014A040801100212110A098C154881402888340F4A0408001001200242AD01122164622070726F6265206D756C7469206164642032303236303531393033313734391A180A166D756C746920412032303236303531393033313734391A180A166D756C746920422032303236303531393033313734391A180A166D756C74692043203230323630353139303331373439200032230800080210EED1F5F1E3331A14334237323145423434303645454434354236313828013800420A08E0F78BD3E49A8CAE5D58006801800101
        """)

        let record = eventRecord(
            text: nil,
            isFromMe: true,
            messageType: 46,
            receiptInfo: receiptInfo
        )

        let poll = record.poll

        XCTAssertEqual(poll?.question, "db probe multi add 20260519031749")
        XCTAssertEqual(poll?.choices.map(\.text), [
            "multi A 20260519031749",
            "multi B 20260519031749",
            "multi C 20260519031749",
        ])
        XCTAssertEqual(poll?.choices.map(\.voteCount), [1, 0, 1])
        XCTAssertEqual(poll?.allowMultipleChoices, true)
        XCTAssertEqual(poll?.hideVoterNames, false)
        XCTAssertTrue(record.isPollMessage)
    }

    func testPollReceiptInfoParsesSingleChoiceAndHiddenVoters() {
        let singleReceiptInfo = Data(hexString: """
        12160A088C487614851318444A04080010014A040801100212110A098C154881402888340F4A0408001001200242A801121E64622070726F62652073696E676C652032303236303531393033313734391A190A1773696E676C6520412032303236303531393033313734391A190A1773696E676C6520422032303236303531393033313734391A190A1773696E676C65204320323032363035313930333137343920013221080110AB8EF6F1E3331A14334244333839434641444238464341423944454128013800420A08B0CBA8F39FCAFD823958006801
        """)
        let hiddenReceiptInfo = Data(hexString: """
        12160A088C487614851318444A04080010014A040801100212110A098C154881402888340F4A0408001001200242AC01121E64622070726F62652068696464656E2032303236303531393033313734391A190A1768696464656E20412032303236303531393033313734391A190A1768696464656E20422032303236303531393033313734391A190A1768696464656E2043203230323630353139303331373439200032230801080210F3CAF6F1E3331A14334237413138353434303145333530364341323028013800420A08F197A5E3EAD899EC73580068017801
        """)

        let single = eventRecord(
            text: nil,
            messageType: 46,
            receiptInfo: singleReceiptInfo
        ).poll
        let hidden = eventRecord(
            text: nil,
            messageType: 46,
            receiptInfo: hiddenReceiptInfo
        ).poll

        XCTAssertEqual(single?.choices.map(\.voteCount), [0, 1, 0])
        XCTAssertEqual(single?.allowMultipleChoices, false)
        XCTAssertEqual(single?.hideVoterNames, false)

        XCTAssertEqual(hidden?.choices.map(\.voteCount), [0, 1, 1])
        XCTAssertEqual(hidden?.allowMultipleChoices, true)
        XCTAssertEqual(hidden?.hideVoterNames, true)
    }

    func testReactionReceiptChangeEmitsReaction() {
        let previousHex = "00"
        let currentHex = "0A14334235303438354437373736333239453432393312143438373631343835313331383434406C69643A04F09F918D"
        let old = receiptSnapshot(hex: previousHex)
        let new = receiptSnapshot(hex: currentHex)

        let events = ChatStorageEventObserver.receiptEvents(
            from: ["message-1": old],
            to: ["message-1": new],
            pollRootIds: [],
            occurredAt: Date(timeIntervalSince1970: 10)
        )

        guard case .message(.changed(let event)) = events.first,
              case .reaction(let reaction) = event.change
        else {
            XCTFail("Expected reaction message event")
            return
        }

        XCTAssertEqual(reaction.messageId, "message-1")
        XCTAssertEqual(reaction.emoji, "👍")
        XCTAssertEqual(reaction.actorJid, "48761485131844@lid")
        XCTAssertEqual(reaction.reactionId, "3B50485D7776329E4293")
    }

    func testReactionReceiptChangeEmitsKeycapEmoji() {
        let previousHex = "00"
        let currentHex = Data("3B50485D7776329E4293 48761485131844@lid reaction 1️⃣".utf8)
            .map { String(format: "%02X", $0) }
            .joined()
        let old = receiptSnapshot(hex: previousHex)
        let new = receiptSnapshot(hex: currentHex)

        let events = ChatStorageEventObserver.receiptEvents(
            from: ["message-1": old],
            to: ["message-1": new],
            pollRootIds: [],
            occurredAt: Date(timeIntervalSince1970: 10)
        )

        guard case .message(.changed(let event)) = events.first,
              case .reaction(let reaction) = event.change
        else {
            XCTFail("Expected reaction message event")
            return
        }

        XCTAssertEqual(reaction.emoji, "1️⃣")
    }

    func testReactionClearEmitsNilEmoji() {
        let previousHex = "0A14334235303438354437373736333239453432393312143438373631343835313331383434406C69643A04F09F918D"
        let currentHex = "0A14334235303438354437373736333239453432393312143438373631343835313331383434406C6964"
        let old = receiptSnapshot(hex: previousHex)
        let new = receiptSnapshot(hex: currentHex)

        let events = ChatStorageEventObserver.receiptEvents(
            from: ["message-1": old],
            to: ["message-1": new],
            pollRootIds: [],
            occurredAt: Date(timeIntervalSince1970: 10)
        )

        guard case .message(.changed(let event)) = events.first,
              case .reaction(let reaction) = event.change
        else {
            XCTFail("Expected reaction clear event")
            return
        }

        XCTAssertNil(reaction.emoji)
        XCTAssertEqual(reaction.actorJid, "48761485131844@lid")
    }

    func testDeliveryOnlyReceiptChangeIsSuppressed() {
        let events = ChatStorageEventObserver.receiptEvents(
            from: ["message-1": receiptSnapshot(hex: "0801")],
            to: ["message-1": receiptSnapshot(hex: "0802")],
            pollRootIds: [],
            occurredAt: Date(timeIntervalSince1970: 10)
        )

        XCTAssertTrue(events.isEmpty)
    }

    func testPollRootReceiptChangeIsSuppressedAsMessageReceipt() {
        let events = ChatStorageEventObserver.receiptEvents(
            from: ["poll-1": receiptSnapshot(messageId: "poll-1", hex: "4201")],
            to: ["poll-1": receiptSnapshot(messageId: "poll-1", hex: "4202")],
            pollRootIds: ["poll-1"],
            occurredAt: Date(timeIntervalSince1970: 10)
        )

        XCTAssertTrue(events.isEmpty)
    }

    func testUnclassifiedReceiptChangeIsSuppressed() {
        let events = ChatStorageEventObserver.receiptEvents(
            from: ["message-1": receiptSnapshot(hex: "4201")],
            to: ["message-1": receiptSnapshot(hex: "4202")],
            pollRootIds: [],
            occurredAt: Date(timeIntervalSince1970: 10)
        )

        XCTAssertTrue(events.isEmpty)
    }

    private func eventRecord(
        contactJid: String = "15551234567@s.whatsapp.net",
        partnerName: String? = nil,
        text: String?,
        mediaLocalPath: String? = nil,
        mediaFileSize: Int64? = nil,
        mediaTitle: String? = nil,
        mediaVCardName: String? = nil,
        mediaLatitude: Double? = nil,
        mediaLongitude: Double? = nil,
        messageDate: Double? = 1,
        isFromMe: Bool = true,
        messageType: Int = 0,
        mediaMetadata: Data? = nil,
        receiptInfo: Data? = nil
    ) -> ChatStorageEventRecord {
        ChatStorageEventRecord(
            rowId: 1,
            contactJid: contactJid,
            partnerName: partnerName,
            stanzaId: "stanza-1",
            text: text,
            isFromMe: isFromMe,
            messageType: messageType,
            messageDate: messageDate,
            parentContactJid: nil,
            parentStanzaId: nil,
            parentIsFromMe: nil,
            mediaLocalPath: mediaLocalPath,
            mediaFileSize: mediaFileSize,
            mediaTitle: mediaTitle,
            mediaVCardName: mediaVCardName,
            mediaLatitude: mediaLatitude,
            mediaLongitude: mediaLongitude,
            mediaMetadata: mediaMetadata,
            receiptInfo: receiptInfo
        )
    }

    private func pollSnapshot(
        optionTexts: [String] = ["A", "B"],
        voteCounts: [Int]
    ) -> ChatStorageEventObserver.PollSnapshot {
        ChatStorageEventObserver.PollSnapshot(
            rowId: 1,
            recipient: "15551234567",
            pollId: "poll-1",
            occurredAt: Date(timeIntervalSince1970: 1),
            isFromMe: true,
            poll: Poll(
                pollId: "poll-1",
                question: "Poll?",
                choices: optionTexts.enumerated().map { index, text in
                    PollChoice(index: index, text: text, voteCount: voteCounts[index])
                },
                allowMultipleChoices: true,
                hideVoterNames: false
            )
        )
    }

    private func receiptSnapshot(
        messageId: String = "message-1",
        hex: String
    ) -> ChatStorageEventObserver.ReceiptSnapshot {
        ChatStorageEventObserver.ReceiptSnapshot(
            rowId: 1,
            messageId: messageId,
            recipient: "15551234567",
            occurredAt: Date(timeIntervalSince1970: 1),
            isFromMe: true,
            receiptDigest: hex,
            receiptHex: hex
        )
    }

}

private extension Data {
    init(hexString: String) {
        let filtered = hexString.filter { !$0.isWhitespace }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(filtered.count / 2)

        var index = filtered.startIndex
        while index < filtered.endIndex {
            let next = filtered.index(index, offsetBy: 2)
            let byte = UInt8(filtered[index..<next], radix: 16) ?? 0
            bytes.append(byte)
            index = next
        }

        self.init(bytes)
    }
}
