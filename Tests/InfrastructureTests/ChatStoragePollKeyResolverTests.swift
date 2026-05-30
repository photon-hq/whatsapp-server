import XCTest
import GRDB
@testable import Domain
@testable import Infrastructure

final class ChatStoragePollKeyResolverTests: XCTestCase {

    func testExtractsStanzaIdFromCurrentDevicePollId() {
        XCTAssertEqual(
            PollIdentifier.stanzaId(
                from: "48761485131844@lid_3B09C28329B22B884D0E_1_0"
            ),
            "3B09C28329B22B884D0E"
        )
    }

    func testExtractsStanzaIdWhenStanzaContainsUnderscores() {
        XCTAssertEqual(
            PollIdentifier.stanzaId(
                from: "48761485131844@lid_sender_3B09C28329B22B884D0E_0_0"
            ),
            "sender_3B09C28329B22B884D0E"
        )
    }

    func testRejectsMalformedPollId() {
        XCTAssertNil(PollIdentifier.stanzaId(from: "not-a-poll-key"))
    }

    func testResolvesPeerPollIdToLocalInboundPollKey() async throws {
        let path = try makeChatStorageDatabase()
        let resolver = ChatStoragePollKeyResolver(
            database: try ChatStorageDatabase(path: path)
        )

        let pollId = try await resolver.localPollId(
            for: "154881402888340@lid_3BB730B6CA80FF723BFE_1_0"
        )

        XCTAssertEqual(pollId, "48761485131844@lid_3BB730B6CA80FF723BFE_0_0")
    }

    private func makeChatStorageDatabase() throws -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("ChatStorage.sqlite")
            .path
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
                        ZCONTACTJID TEXT NOT NULL
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
                        ZMESSAGETYPE INTEGER NOT NULL
                    )
                    """
            )

            try db.execute(
                sql: """
                    INSERT INTO ZWACHATSESSION (Z_PK, ZCONTACTJID)
                    VALUES (1, '48761485131844@lid')
                    """
            )

            try db.execute(
                sql: """
                    INSERT INTO ZWAMESSAGE
                        (Z_PK, ZCHATSESSION, ZSTANZAID, ZISFROMME, ZMESSAGETYPE)
                    VALUES
                        (10, 1, '3BB730B6CA80FF723BFE', 0, 46)
                    """
            )
        }

        return path
    }

}
