import Foundation
import GRDB
import XCTest
@testable import Domain
@testable import Infrastructure

final class ChatStoragePollStoreReadbackTests: XCTestCase {

    func testFindsCreatedOutboundPollRootRow() async throws {
        let path = try makeChatStorageDatabase()
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStoragePollStore(database: database)

        let result = try await readback.createdPoll(
            matching: PollCreationReadbackQuery(
                pollId: "48761485131844@lid_3B40A0A41C85DB037EEA_1_0",
                recipient: "19084301481"
            )
        )

        XCTAssertEqual(result?.pollId, "48761485131844@lid_3B40A0A41C85DB037EEA_1_0")
        XCTAssertEqual(result?.poll.question, "db probe multi add 20260519031749")
        XCTAssertNotNil(result?.digest)
    }

    func testDetectsPollUpdateDigestChange() async throws {
        let path = try makeChatStorageDatabase()
        let pool = try DatabasePool(path: path)
        let database = try ChatStorageDatabase(path: path)
        let readback = ChatStoragePollStore(database: database)
        let pollId = "48761485131844@lid_3B40A0A41C85DB037EEA_1_0"

        let before = try await readback.currentPollUpdate(pollId: pollId)
        XCTAssertNotNil(before?.digest)

        let unchanged = try await readback.updatedPoll(
            matching: PollUpdateReadbackQuery(
                pollId: pollId,
                previousDigest: before?.digest
            )
        )
        XCTAssertNil(unchanged)

        try await pool.write { db in
            try db.execute(
                sql: "UPDATE ZWAMEDIAITEM SET ZMETADATA = ? WHERE Z_PK = 20",
                arguments: [Data("poll metadata after vote".utf8)]
            )
        }

        let changed = try await readback.updatedPoll(
            matching: PollUpdateReadbackQuery(
                pollId: pollId,
                previousDigest: before?.digest
            )
        )
        XCTAssertEqual(changed?.pollId, pollId)
        XCTAssertNotEqual(changed?.digest, before?.digest)
    }

    func testReadbackResultMatchesSamePollAcrossDeviceLocalKeys() {
        let result = PollMutationReadbackResult(
            poll: Poll(
                pollId: "48761485131844@lid_poll-stanza_0_0",
                question: "Lunch?",
                choices: [
                    PollChoice(index: 0, text: "Sushi", voteCount: 0),
                    PollChoice(index: 1, text: "Pizza", voteCount: 0)
                ],
                allowMultipleChoices: false,
                hideVoterNames: false
            ),
            digest: "digest"
        )

        XCTAssertTrue(
            result.isSamePoll(as: "154881402888340@lid_poll-stanza_1_0")
        )
        XCTAssertFalse(
            result.isSamePoll(as: "154881402888340@lid_other-stanza_1_0")
        )
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
                        ZCHATSESSION INTEGER NOT NULL,
                        ZSTANZAID TEXT NOT NULL,
                        ZISFROMME BOOLEAN NOT NULL,
                        ZMESSAGETYPE INTEGER NOT NULL DEFAULT 0,
                        ZMEDIAITEM INTEGER,
                        ZMESSAGEINFO INTEGER
                    )
                    """
            )

            try db.execute(
                sql: """
                    CREATE TABLE ZWAMEDIAITEM (
                        Z_PK INTEGER PRIMARY KEY,
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
                    VALUES (1, '48761485131844@lid', '+1 (908) 430-1481')
                    """
            )

            try db.execute(
                sql: """
                    INSERT INTO ZWAMEDIAITEM (Z_PK, ZMETADATA)
                    VALUES (20, ?)
                    """,
                arguments: [Data(hexString: "A204202B005EC7C3C34E94A949E0D23C5FDCE6D252E01F3E07CC85CEC667F12B5BB387")]
            )

            try db.execute(
                sql: """
                    INSERT INTO ZWAMESSAGEINFO (Z_PK, ZMESSAGE, ZRECEIPTINFO)
                    VALUES (30, 10, ?)
                    """,
                arguments: [Data(hexString: """
                    12160A088C487614851318444A04080010014A040801100212110A098C154881402888340F4A0408001001200242AD01122164622070726F6265206D756C7469206164642032303236303531393033313734391A180A166D756C746920412032303236303531393033313734391A180A166D756C746920422032303236303531393033313734391A180A166D756C74692043203230323630353139303331373439200032230800080210EED1F5F1E3331A14334237323145423434303645454434354236313828013800420A08E0F78BD3E49A8CAE5D58006801800101
                    """)]
            )

            try db.execute(
                sql: """
                    INSERT INTO ZWAMESSAGE
                        (Z_PK, ZCHATSESSION, ZSTANZAID, ZISFROMME, ZMESSAGETYPE, ZMEDIAITEM, ZMESSAGEINFO)
                    VALUES
                        (10, 1, '3B40A0A41C85DB037EEA', 1, 46, 20, 30)
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
