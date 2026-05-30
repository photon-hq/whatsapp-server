import Domain
import Foundation
import GRDB

package struct ChatStoragePollKeyResolver: Sendable {

    let database: ChatStorageDatabase

    package init(database: ChatStorageDatabase) {
        self.database = database
    }

    package func localPollId(for pollId: String) async throws -> String {
        guard let stanzaId = PollIdentifier.stanzaId(from: pollId) else {
            return pollId
        }

        if try await exactPollExists(pollId: pollId) {
            return pollId
        }

        for _ in 0..<10 {
            if let localPollId = try await pollKey(stanzaId: stanzaId) {
                return localPollId
            }

            try await Task.sleep(for: .milliseconds(500))
        }

        return pollId
    }

    private func exactPollExists(pollId: String) async throws -> Bool {
        try await database.read { db in
            try Bool.fetchOne(
                db,
                sql: """
                    SELECT 1
                    FROM ZWAMESSAGE m
                    JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
                    WHERE m.ZMESSAGETYPE IN (13, 46)
                      AND c.ZCONTACTJID || '_' || m.ZSTANZAID || '_' || m.ZISFROMME || '_0' = ?
                    LIMIT 1
                    """,
                arguments: [pollId]
            ) ?? false
        }
    }

    private func pollKey(stanzaId: String) async throws -> String? {
        let rows = try await database.read { db in
            try PollKeyRow.fetchAll(
                db,
                sql: """
                    SELECT
                        c.ZCONTACTJID AS contactJid,
                        m.ZSTANZAID AS stanzaId,
                        m.ZISFROMME AS isFromMe
                    FROM ZWAMESSAGE m
                    JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
                    WHERE m.ZMESSAGETYPE IN (13, 46)
                      AND m.ZSTANZAID = ?
                    ORDER BY m.Z_PK DESC
                    """,
                arguments: [stanzaId]
            )
        }

        return rows.first?.uniqueKey
    }

}

private struct PollKeyRow: Decodable, FetchableRecord {
    let contactJid: String
    let stanzaId: String
    let isFromMe: Bool

    var uniqueKey: String {
        "\(contactJid)_\(stanzaId)_\(isFromMe ? 1 : 0)_0"
    }
}
