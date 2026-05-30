import Foundation
import GRDB
import XCTest
@testable import Domain
@testable import Infrastructure

final class ChatStorageMessageMutationReadbackTests: XCTestCase {

    func testFindsSentTextByUniqueKeyAndReplyTarget() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStorageMessageMutationReadback(database: database)

        let result = try await readback.sentText(
            matching: SentTextReadbackQuery(
                messageId: "245033018110026@lid_reply-stanza_1_0",
                recipient: "15551619824",
                text: "reply text",
                replyToMessageId: "245033018110026@lid_parent-stanza_0_0"
            )
        )

        XCTAssertEqual(result?.messageId, "245033018110026@lid_reply-stanza_1_0")
        XCTAssertEqual(result?.recipient, "15551619824")
        XCTAssertEqual(result?.isFromMe, true)
    }

    func testFindsReplyTargetFromMediaMetadataWhenParentColumnIsEmpty() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStorageMessageMutationReadback(database: database)

        let result = try await readback.sentText(
            matching: SentTextReadbackQuery(
                messageId: "245033018110026@lid_metadata-reply-stanza_1_0",
                recipient: "15551619824",
                text: "metadata reply text",
                replyToMessageId: "245033018110026@lid_parent-stanza_0_0"
            )
        )

        XCTAssertEqual(result?.replyToMessageId, "245033018110026@lid_parent-stanza_0_0")
    }

    func testSentTextRequiresReplyTargetWhenRequested() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStorageMessageMutationReadback(database: database)

        let result = try await readback.sentText(
            matching: SentTextReadbackQuery(
                messageId: "245033018110026@lid_plain-stanza_1_0",
                recipient: "15551619824",
                text: "plain text",
                replyToMessageId: "245033018110026@lid_parent-stanza_0_0"
            )
        )

        XCTAssertNil(result)
    }

    func testRejectsSentTextUntilSuccessfulSendSignalAppears() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStorageMessageMutationReadback(database: database)

        let pending = try await readback.sentText(
            matching: SentTextReadbackQuery(
                messageId: "245033018110026@lid_pending-stanza_1_0",
                recipient: "15551619824",
                text: "pending text"
            )
        )
        let failed = try await readback.sentText(
            matching: SentTextReadbackQuery(
                messageId: "245033018110026@lid_failed-stanza_1_0",
                recipient: "15551619824",
                text: "failed text"
            )
        )

        XCTAssertNil(pending)
        XCTAssertNil(failed)
    }

    func testFindsSentMediaByTypeCaptionRecipientAndStartTime() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStorageMessageMutationReadback(database: database)

        let result = try await readback.sentMedia(
            matching: SentMediaReadbackQuery(
                recipient: "15551619824",
                type: .image,
                caption: "image caption",
                notBefore: Date(timeIntervalSince1970: 978_307_200 + 9)
            )
        )

        XCTAssertEqual(result?.messageId, "245033018110026@lid_image-stanza_1_0")
    }

    func testFindsSentMediaWithUploadedStatusOne() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStorageMessageMutationReadback(database: database)

        let result = try await readback.sentMedia(
            matching: SentMediaReadbackQuery(
                recipient: "15551619824",
                type: .image,
                caption: "uploaded status one image caption",
                notBefore: Date(timeIntervalSince1970: 978_307_200 + 17)
            )
        )

        XCTAssertEqual(result?.messageId, "245033018110026@lid_status-one-image-stanza_1_0")
    }

    func testRejectsSentMediaUntilSuccessfulUploadSignalAppears() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStorageMessageMutationReadback(database: database)

        let pending = try await readback.sentMedia(
            matching: SentMediaReadbackQuery(
                recipient: "15551619824",
                type: .video,
                caption: "pending video caption",
                notBefore: Date(timeIntervalSince1970: 978_307_200 + 10)
            )
        )

        XCTAssertNil(pending)
    }

    func testReactionRequiresReceiptDigestChangeAndEmoji() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStorageMessageMutationReadback(database: database)

        let previous = try await readback.receipt(
            forMessageId: "245033018110026@lid_parent-stanza_0_0"
        )
        let changed = try await readback.reaction(
            matching: ReactionReadbackQuery(
                messageId: "245033018110026@lid_parent-stanza_0_0",
                emoji: "👍",
                previousReceiptDigest: "different"
            )
        )
        let unchanged = try await readback.reaction(
            matching: ReactionReadbackQuery(
                messageId: "245033018110026@lid_parent-stanza_0_0",
                emoji: "👍",
                previousReceiptDigest: previous?.receiptDigest
            )
        )

        XCTAssertNotNil(previous?.receiptDigest)
        XCTAssertEqual(changed?.receipt.messageId, "245033018110026@lid_parent-stanza_0_0")
        XCTAssertEqual(changed?.reaction.emoji, "👍")
        XCTAssertNil(unchanged)
    }

    func testReactionReadbackSupportsKeycapEmoji() async throws {
        let path = try makeChatStorageDatabase(receiptInfo: Data("reaction 1️⃣".utf8))
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStorageMessageMutationReadback(database: database)

        let changed = try await readback.reaction(
            matching: ReactionReadbackQuery(
                messageId: "245033018110026@lid_parent-stanza_0_0",
                emoji: "1️⃣",
                previousReceiptDigest: "different"
            )
        )

        XCTAssertEqual(changed?.reaction.emoji, "1️⃣")
    }

    private func makeChatStorageDatabase(receiptInfo: Data = Data("reaction 👍".utf8)) throws -> String {
        let path = temporaryDatabasePath()
        let directory = (path as NSString).deletingLastPathComponent

        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        let pool = try DatabasePool(path: path)

        try pool.write { db in
            try db.execute(
                sql: """
                    CREATE TABLE ZWACHATSESSION (
                        Z_PK INTEGER PRIMARY KEY,
                        ZCONTACTJID TEXT NOT NULL,
                        ZPARTNERNAME TEXT
                    )
                    """
            )

            try db.execute(
                sql: """
                    CREATE TABLE ZWAMESSAGE (
                        Z_PK INTEGER PRIMARY KEY,
                        ZSORT INTEGER NOT NULL,
                        ZCHATSESSION INTEGER NOT NULL,
                        ZSTANZAID TEXT NOT NULL,
                        ZTEXT TEXT,
                        ZISFROMME BOOLEAN NOT NULL,
                        ZMESSAGESTATUS INTEGER,
                        ZMESSAGEERRORSTATUS INTEGER,
                        ZMESSAGETYPE INTEGER NOT NULL DEFAULT 0,
                        ZMESSAGEDATE DOUBLE,
                        ZSENTDATE DOUBLE,
                        ZFROMJID TEXT,
                        ZTOJID TEXT,
                        ZPUSHNAME TEXT,
                        ZMEDIAITEM INTEGER,
                        ZMESSAGEINFO INTEGER,
                        ZPARENTMESSAGE INTEGER
                    )
                    """
            )

            try db.execute(
                sql: """
                    CREATE TABLE ZWAMEDIAITEM (
                        Z_PK INTEGER PRIMARY KEY,
                        ZFILESIZE INTEGER,
                        ZCLOUDSTATUS INTEGER,
                        ZMEDIALOCALPATH TEXT,
                        ZTITLE TEXT,
                        ZMEDIAURL TEXT,
                        ZVCARDNAME TEXT,
                        ZVCARDSTRING TEXT,
                        ZLATITUDE DOUBLE,
                        ZLONGITUDE DOUBLE,
                        ZTHUMBNAILLOCALPATH TEXT,
                        ZXMPPTHUMBPATH TEXT,
                        ZMEDIAURLDATE DOUBLE,
                        ZMETADATA BLOB
                    )
                    """
            )

            try db.execute(
                sql: """
                    CREATE TABLE ZWAMESSAGEINFO (
                        Z_PK INTEGER PRIMARY KEY,
                        ZMESSAGE INTEGER,
                        ZRECEIPTINFO BLOB
                    )
                    """
            )

            try db.execute(
                sql: """
                    INSERT INTO ZWACHATSESSION (Z_PK, ZCONTACTJID, ZPARTNERNAME)
                    VALUES (1, '245033018110026@lid', '+1 (555) 161-9824')
                    """
            )

            try db.execute(
                sql: """
                    INSERT INTO ZWAMEDIAITEM (Z_PK, ZFILESIZE, ZCLOUDSTATUS, ZMEDIALOCALPATH, ZTITLE, ZMEDIAURL, ZMETADATA)
                    VALUES
                        (20, 42, 2, 'Media/demo.jpg', 'image caption', 'https://mmg.whatsapp.net/demo.jpg', NULL),
                        (21, 100, 1, 'Media/pending.mp4', 'pending video caption', NULL, NULL),
                        (22, 0, NULL, NULL, NULL, NULL, ?),
                        (23, 42, 2, 'Media/status-one.jpg', 'uploaded status one image caption', 'https://mmg.whatsapp.net/status-one.jpg', NULL)
                    """,
                arguments: [Data("parent-stanza quoted text".utf8)]
            )

            try db.execute(
                sql: """
                    INSERT INTO ZWAMESSAGEINFO (Z_PK, ZMESSAGE, ZRECEIPTINFO)
                    VALUES (30, 10, ?)
                    """,
                arguments: [receiptInfo]
            )

            try db.execute(
                sql: """
                    INSERT INTO ZWAMESSAGE
                        (Z_PK, ZSORT, ZCHATSESSION, ZSTANZAID, ZTEXT, ZISFROMME, ZMESSAGESTATUS, ZMESSAGEERRORSTATUS, ZMESSAGETYPE, ZMESSAGEDATE, ZSENTDATE, ZFROMJID, ZTOJID, ZPUSHNAME, ZMEDIAITEM, ZMESSAGEINFO, ZPARENTMESSAGE)
                    VALUES
                        (10, 10, 1, 'parent-stanza', 'parent text', 0, 8, 0, 0, 10, 10, NULL, NULL, NULL, NULL, 30, NULL),
                        (11, 11, 1, 'plain-stanza', 'plain text', 1, 6, 0, 0, 11, 11, NULL, NULL, NULL, NULL, NULL, NULL),
                        (12, 12, 1, 'reply-stanza', 'reply text', 1, 6, 0, 0, 12, 12, NULL, NULL, NULL, NULL, NULL, 10),
                        (13, 13, 1, 'image-stanza', NULL, 1, 6, 0, 1, 13, 13, NULL, NULL, NULL, 20, NULL, NULL),
                        (14, 14, 1, 'pending-stanza', 'pending text', 1, 9, 0, 0, 14, 14, NULL, NULL, NULL, NULL, NULL, NULL),
                        (15, 15, 1, 'failed-stanza', 'failed text', 1, 6, 2, 0, 15, 15, NULL, NULL, NULL, NULL, NULL, NULL),
                        (16, 16, 1, 'pending-video-stanza', NULL, 1, 9, 0, 2, 16, 16, NULL, NULL, NULL, 21, NULL, NULL),
                        (17, 17, 1, 'metadata-reply-stanza', 'metadata reply text', 1, 6, 0, 0, 17, 17, NULL, NULL, NULL, 22, NULL, NULL),
                        (18, 18, 1, 'status-one-image-stanza', NULL, 1, 1, 0, 1, 18, 18, NULL, NULL, NULL, 23, NULL, NULL)
                    """
            )
        }

        return path
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("ChatStorage.sqlite")
            .path
    }

}
