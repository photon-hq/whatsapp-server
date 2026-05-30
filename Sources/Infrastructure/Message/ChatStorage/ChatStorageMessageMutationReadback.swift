import Domain
import Foundation
import GRDB

package struct ChatStorageMessageMutationReadback: MessageMutationReadback, Sendable {

    let database: ChatStorageDatabase

    package init(database: ChatStorageDatabase) {
        self.database = database
    }

    package func message(
        forMessageId messageId: String
    ) async throws -> MessageSnapshot? {
        guard let key = ChatStorageMessageKey(messageId: messageId) else {
            return nil
        }

        return try await messageRows(
            contactJid: key.contactJid,
            stanzaId: key.stanzaId,
            isFromMe: key.isFromMe
        ).first?.snapshot
    }

    package func sentText(
        matching query: SentTextReadbackQuery
    ) async throws -> MessageSnapshot? {
        guard let key = ChatStorageMessageKey(messageId: query.messageId) else {
            return nil
        }

        return try await messageRows(
            contactJid: key.contactJid,
            stanzaId: key.stanzaId,
            isFromMe: key.isFromMe
        ).first { row in
            row.messageId == query.messageId
                && row.matches(recipient: query.recipient)
                && row.isFromMe
                && row.hasSuccessfulSendSignal
                && row.matches(replyToMessageId: query.replyToMessageId)
        }?.snapshot
    }

    package func sentMedia(
        matching query: SentMediaReadbackQuery
    ) async throws -> MessageSnapshot? {
        let notBefore = WhatsAppDate.storedSeconds(from: query.notBefore.addingTimeInterval(-1))
        return try await database.read { db in
            let rows = try ChatStorageMessageRecord.fetchAll(
                db,
                sql: ChatStorageMessageRecord.selectSQL + """
                    WHERE m.ZSTANZAID IS NOT NULL
                      AND m.ZSTANZAID != ''
                      AND m.ZISFROMME = 1
                      AND m.ZMESSAGETYPE = ?
                      AND m.ZMESSAGEDATE >= ?
                    ORDER BY m.Z_PK DESC
                    LIMIT 20
                    """,
                arguments: [messageType(for: query.type), notBefore]
            )

            return rows.first { row in
                row.matches(recipient: query.recipient)
                    && row.hasSuccessfulMediaSendSignal
                    && row.hasUploadedMedia
                    && row.mediaCaptionMatches(query.caption)
            }?.snapshot
        }
    }

    package func receipt(
        forMessageId messageId: String
    ) async throws -> MessageReceiptReadback? {
        try await receiptRow(messageId: messageId)?.readback
    }

    package func reaction(
        matching query: ReactionReadbackQuery
    ) async throws -> MessageReactionReadback? {
        guard let row = try await receiptRow(messageId: query.messageId),
              row.receiptDigest != query.previousReceiptDigest,
              row.receiptText.contains(query.emoji)
        else {
            return nil
        }

        return row.reactionReadback(previousReceiptHex: nil)
    }

    private func messageRows(
        contactJid: String,
        stanzaId: String,
        isFromMe: Bool
    ) async throws -> [ChatStorageMessageRecord] {
        try await database.read { db in
            try ChatStorageMessageRecord.fetchAll(
                db,
                sql: ChatStorageMessageRecord.selectSQL + """
                    WHERE c.ZCONTACTJID = ?
                      AND m.ZSTANZAID = ?
                      AND m.ZISFROMME = ?
                    ORDER BY m.Z_PK DESC
                    LIMIT 1
                    """,
                arguments: [
                    contactJid,
                    stanzaId,
                    isFromMe ? 1 : 0,
                ]
            )
        }
    }

    private func receiptRow(messageId: String) async throws -> MessageReceiptReadbackRecord? {
        guard let key = ChatStorageMessageKey(messageId: messageId) else {
            return nil
        }

        return try await database.read { db in
            try MessageReceiptReadbackRecord.fetchOne(
                db,
                sql: """
                    SELECT
                        m.Z_PK AS rowId,
                        c.ZCONTACTJID AS contactJid,
                        m.ZSTANZAID AS stanzaId,
                        m.ZISFROMME AS isFromMe,
                        hex(info.ZRECEIPTINFO) AS receiptHex
                    FROM ZWAMESSAGE m
                    JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
                    JOIN ZWAMESSAGEINFO info ON info.Z_PK = m.ZMESSAGEINFO
                    WHERE c.ZCONTACTJID = ?
                      AND m.ZSTANZAID = ?
                      AND m.ZISFROMME = ?
                      AND info.ZRECEIPTINFO IS NOT NULL
                      AND length(info.ZRECEIPTINFO) > 0
                    ORDER BY m.Z_PK DESC
                    LIMIT 1
                    """,
                arguments: [
                    key.contactJid,
                    key.stanzaId,
                    key.isFromMe ? 1 : 0,
                ]
            )
        }
    }

    private func messageType(for type: MediaType) -> Int {
        switch type {
        case .image:
            1
        case .video:
            2
        }
    }

}

private struct MessageReceiptReadbackRecord: Decodable, FetchableRecord, Sendable {

    let rowId: Int64
    let contactJid: String
    let stanzaId: String
    let isFromMe: Bool
    let receiptHex: String

    enum CodingKeys: String, CodingKey {
        case rowId
        case contactJid
        case stanzaId
        case isFromMe
        case receiptHex
    }

    var messageId: String {
        "\(contactJid)_\(stanzaId)_\(isFromMe ? 1 : 0)_0"
    }

    var receiptDigest: String {
        SHA256Hex.string(receiptHex)
    }

    var receiptText: String {
        String(decoding: HexBytes.decode(receiptHex), as: UTF8.self)
    }

    var readback: MessageReceiptReadback {
        MessageReceiptReadback(
            messageId: messageId,
            receiptDigest: receiptDigest
        )
    }

    func reactionReadback(previousReceiptHex: String?) -> MessageReactionReadback? {
        guard let reaction = reaction(previousReceiptHex: previousReceiptHex) else {
            return nil
        }

        return MessageReactionReadback(receipt: readback, reaction: reaction)
    }

    private func reaction(previousReceiptHex: String?) -> MessageReactionSnapshot? {
        let previousEmoji = previousReceiptHex.flatMap(ReceiptInfoParser.lastEmoji)
        let currentEmoji = ReceiptInfoParser.lastEmoji(inHex: receiptHex)
        guard previousEmoji != currentEmoji else {
            return nil
        }

        return MessageReactionSnapshot(
            messageId: messageId,
            emoji: currentEmoji,
            actorJid: ReceiptInfoParser.lastLid(inHex: receiptHex)
                ?? previousReceiptHex.flatMap(ReceiptInfoParser.lastLid),
            reactionId: ReceiptInfoParser.lastStanzaId(inHex: receiptHex)
                ?? previousReceiptHex.flatMap(ReceiptInfoParser.lastStanzaId)
        )
    }

}
