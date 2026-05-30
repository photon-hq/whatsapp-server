import Foundation
import GRDB
import XCTest
@testable import Domain
@testable import Infrastructure

final class ChatStorageMessageQueryingTests: XCTestCase {

    func testListInChatFindsLidChatByFormattedPartnerNameAndReturnsFullMessages() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let querying = ChatStorageMessageQuerying(database: database)

        let page = try await querying.listChatMessages(
            query: ChatMessagesQuery(recipient: "15551619824", pageSize: 10)
        )

        XCTAssertEqual(page.entries.count, 2)
        XCTAssertEqual(page.entries[0].message.messageId, "245033018110026@lid_stanza-new_1_0")
        XCTAssertEqual(page.entries[0].message.text, "new")
        XCTAssertEqual(page.entries[0].message.isFromMe, true)
        XCTAssertEqual(page.entries[0].message.messageDate, Date(timeIntervalSince1970: 978_307_202))
        XCTAssertEqual(page.entries[1].message.messageId, "245033018110026@lid_stanza-old_0_0")
        XCTAssertEqual(page.entries[1].message.isFromMe, false)
        XCTAssertNil(page.nextCursor)
    }

    func testListRecentPagesStablyWithSnapshotAndCursor() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let querying = ChatStorageMessageQuerying(database: database)

        let first = try await querying.listRecentMessages(
            query: RecentMessagesQuery(pageSize: 1)
        )
        let second = try await querying.listRecentMessages(
            query: RecentMessagesQuery(
                pageSize: 1,
                snapshotRowId: first.snapshotRowId,
                cursor: first.nextCursor
            )
        )

        XCTAssertEqual(first.entries.map(\.message.text), ["new"])
        XCTAssertEqual(second.entries.map(\.message.text), ["old"])
        XCTAssertEqual(first.snapshotRowId, 11)
    }

    func testGetMessageReturnsFullSnapshot() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let querying = ChatStorageMessageQuerying(database: database)

        let message = try await querying.getMessage(
            messageId: "245033018110026@lid_stanza-new_1_0"
        )

        XCTAssertEqual(message?.recipient, "15551619824")
        XCTAssertEqual(message?.chatJid, "245033018110026@lid")
        XCTAssertEqual(message?.messageStatus, 6)
        XCTAssertEqual(message?.messageErrorStatus, 0)
    }

    private func makeChatStorageDatabase() throws -> String {
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
                    INSERT INTO ZWAMESSAGE
                        (Z_PK, ZSORT, ZCHATSESSION, ZSTANZAID, ZTEXT, ZISFROMME, ZMESSAGESTATUS, ZMESSAGEERRORSTATUS, ZMESSAGETYPE, ZMESSAGEDATE, ZSENTDATE)
                    VALUES
                        (10, 10, 1, 'stanza-old', 'old', 0, 8, 0, 0, 1.0, 1.0),
                        (11, 11, 1, 'stanza-new', 'new', 1, 6, 0, 0, 2.0, 2.0)
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
