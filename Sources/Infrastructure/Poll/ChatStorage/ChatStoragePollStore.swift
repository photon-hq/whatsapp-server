import Domain
import Foundation
import GRDB

package struct ChatStoragePollStore: GetPoll, PollMutationReadback, Sendable {

    let database: ChatStorageDatabase

    package init(database: ChatStorageDatabase) {
        self.database = database
    }

    package func getPoll(pollId: String) async throws -> Poll {
        guard let row = try await pollRow(pollId: pollId),
              let poll = row.poll
        else {
            throw DomainError(.pollNotFound, "Poll not found in ChatStorage")
                .with("poll_id", pollId)
        }

        return poll
    }

    package func createdPoll(
        matching query: PollCreationReadbackQuery
    ) async throws -> PollMutationReadbackResult? {
        // `pollRow` already matches on the authoritative poll id
        // (contactJid + stanzaId + isFromMe) returned by the helper, so an extra
        // phone-recipient guard only produces false timeouts for modern
        // @lid-addressed sessions (e.g. named contacts / message-yourself).
        guard let row = try await pollRow(pollId: query.pollId) else {
            return nil
        }

        return row.readback
    }

    package func currentPollUpdate(
        pollId: String
    ) async throws -> PollMutationReadbackResult? {
        try await pollRow(pollId: pollId)?.readback
    }

    package func updatedPoll(
        matching query: PollUpdateReadbackQuery
    ) async throws -> PollMutationReadbackResult? {
        guard let row = try await pollRow(pollId: query.pollId),
              row.digest != query.previousDigest
        else {
            return nil
        }

        return row.readback
    }

    private func pollRow(pollId: String) async throws -> PollRow? {
        let stanzaId = PollIdentifier.stanzaId(from: pollId)

        return try await database.read { db in
            try PollRow.fetchOne(
                db,
                sql: """
                    SELECT
                        c.ZCONTACTJID AS contactJid,
                        c.ZPARTNERNAME AS partnerName,
                        m.ZSTANZAID AS stanzaId,
                        m.ZISFROMME AS isFromMe,
                        media.ZMETADATA AS mediaMetadata,
                        info.ZRECEIPTINFO AS receiptInfo
                    FROM ZWAMESSAGE m
                    JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
                    LEFT JOIN ZWAMEDIAITEM media ON media.Z_PK = m.ZMEDIAITEM
                    LEFT JOIN ZWAMESSAGEINFO info ON info.Z_PK = m.ZMESSAGEINFO
                    WHERE m.ZMESSAGETYPE IN (13, 46)
                      AND m.ZSTANZAID IS NOT NULL
                      AND m.ZSTANZAID != ''
                      AND (
                        c.ZCONTACTJID || '_' || m.ZSTANZAID || '_' || m.ZISFROMME || '_0' = ?
                        OR m.ZSTANZAID = ?
                      )
                    ORDER BY
                      CASE
                        WHEN c.ZCONTACTJID || '_' || m.ZSTANZAID || '_' || m.ZISFROMME || '_0' = ? THEN 0
                        ELSE 1
                      END,
                      m.ZISFROMME DESC,
                      m.Z_PK DESC
                    LIMIT 1
                    """,
                arguments: [pollId, stanzaId, pollId]
            )
        }
    }

}

private struct PollRow: Decodable, FetchableRecord, Sendable {

    let contactJid: String
    let partnerName: String?
    let stanzaId: String
    let isFromMe: Bool
    let mediaMetadata: Data?
    let receiptInfo: Data?

    var uniqueKey: String {
        "\(contactJid)_\(stanzaId)_\(isFromMe ? 1 : 0)_0"
    }

    var poll: Poll? {
        WhatsAppPollSnapshotParser.parse(
            pollId: uniqueKey,
            metadata: mediaMetadata,
            receiptInfo: receiptInfo
        )
    }

    var digest: String? {
        let material = [receiptInfo, mediaMetadata]
            .compactMap { $0 }
            .map { $0.base64EncodedString() }
            .joined(separator: "|")

        guard !material.isEmpty else {
            return nil
        }

        return SHA256Hex.string(material)
    }

    var readback: PollMutationReadbackResult? {
        guard let poll else { return nil }

        return PollMutationReadbackResult(poll: poll, digest: digest)
    }

    var recipient: String {
        ChatStorageRecipient(
            contactJid: contactJid,
            partnerName: partnerName
        ).publicValue
    }

    func matches(recipient: String) -> Bool {
        ChatStorageRecipient(
            contactJid: contactJid,
            partnerName: partnerName
        ).matches(recipient)
    }

}
