import Domain
import GRDB

package struct ChatStorageMessageQuerying: MessageQuerying, Sendable {

    let database: ChatStorageDatabase

    package init(database: ChatStorageDatabase) {
        self.database = database
    }

    package func getMessage(messageId: String) async throws -> MessageSnapshot? {
        guard let key = ChatStorageMessageKey(messageId: messageId) else {
            return nil
        }

        return try await database.read { db in
            try ChatStorageMessageRecord.fetchOne(
                db,
                sql: ChatStorageMessageRecord.selectSQL + """
                    WHERE c.ZCONTACTJID = ?
                      AND m.ZSTANZAID = ?
                      AND m.ZISFROMME = ?
                    ORDER BY m.Z_PK DESC
                    LIMIT 1
                    """,
                arguments: [
                    key.contactJid,
                    key.stanzaId,
                    key.isFromMe ? 1 : 0,
                ]
            )?.snapshot
        }
    }

    package func listRecentMessages(query: RecentMessagesQuery) async throws -> MessagePageSlice {
        try await database.read { db in
            try listMessagePage(
                db,
                query: PageQuery(
                    pageSize: query.pageSize,
                    snapshotRowId: query.snapshotRowId,
                    cursor: query.cursor,
                    isFromMe: query.isFromMe,
                    before: query.before.map(WhatsAppDate.storedSeconds),
                    after: query.after.map(WhatsAppDate.storedSeconds),
                    chatSessionIds: nil
                )
            )
        }
    }

    package func listChatMessages(query: ChatMessagesQuery) async throws -> MessagePageSlice {
        try await database.read { db in
            let sessionIds = try chatSessionIds(matching: query.recipient, db: db)
            guard !sessionIds.isEmpty else {
                return MessagePageSlice(entries: [], snapshotRowId: 0, nextCursor: nil)
            }

            return try listMessagePage(
                db,
                query: PageQuery(
                    pageSize: query.pageSize,
                    snapshotRowId: query.snapshotRowId,
                    cursor: query.cursor,
                    isFromMe: query.isFromMe,
                    before: query.before.map(WhatsAppDate.storedSeconds),
                    after: query.after.map(WhatsAppDate.storedSeconds),
                    chatSessionIds: sessionIds
                )
            )
        }
    }

}

private extension ChatStorageMessageQuerying {

    struct PageQuery {
        let pageSize: Int
        let snapshotRowId: Int64?
        let cursor: MessagePageCursor?
        let isFromMe: Bool?
        let before: Double?
        let after: Double?
        let chatSessionIds: [Int64]?
    }

    func listMessagePage(
        _ db: Database,
        query: PageQuery
    ) throws -> MessagePageSlice {
        let snapshotRowId = try query.snapshotRowId ?? maxMessageRowId(db)
        var clauses = [
            "m.ZSTANZAID IS NOT NULL",
            "m.ZSTANZAID != ''",
            "m.Z_PK <= ?",
        ]
        var arguments: [any DatabaseValueConvertible] = [snapshotRowId]

        if let chatSessionIds = query.chatSessionIds {
            clauses.append("m.ZCHATSESSION IN (\(placeholders(chatSessionIds.count)))")
            arguments.append(contentsOf: chatSessionIds)
        }

        if let isFromMe = query.isFromMe {
            clauses.append("m.ZISFROMME = ?")
            arguments.append(isFromMe ? 1 : 0)
        }

        if let before = query.before {
            clauses.append("m.ZMESSAGEDATE < ?")
            arguments.append(before)
        }

        if let after = query.after {
            clauses.append("m.ZMESSAGEDATE > ?")
            arguments.append(after)
        }

        if let cursor = query.cursor {
            clauses.append("(m.ZSORT < ? OR (m.ZSORT = ? AND m.Z_PK < ?))")
            arguments.append(contentsOf: [cursor.sort, cursor.sort, cursor.rowId])
        }

        arguments.append(query.pageSize + 1)

        let rows = try ChatStorageMessageRecord.fetchAll(
            db,
            sql: ChatStorageMessageRecord.selectSQL + """
                WHERE \(clauses.joined(separator: " AND "))
                ORDER BY m.ZSORT DESC, m.Z_PK DESC
                LIMIT ?
                """,
            arguments: StatementArguments(arguments)
        )

        let pageRows = Array(rows.prefix(query.pageSize))
        let entries = pageRows.map {
            MessagePageEntry(message: $0.snapshot, cursor: $0.cursor)
        }

        return MessagePageSlice(
            entries: entries,
            snapshotRowId: snapshotRowId,
            nextCursor: rows.count > query.pageSize ? entries.last?.cursor : nil
        )
    }

    func maxMessageRowId(_ db: Database) throws -> Int64 {
        try Int64.fetchOne(db, sql: "SELECT COALESCE(MAX(Z_PK), 0) FROM ZWAMESSAGE") ?? 0
    }

    func chatSessionIds(matching recipient: String, db: Database) throws -> [Int64] {
        try ChatStorageChatSessionRecord.fetchAll(
            db,
            sql: """
                SELECT
                    Z_PK AS rowId,
                    ZCONTACTJID AS contactJid,
                    ZPARTNERNAME AS partnerName
                FROM ZWACHATSESSION
                """
        )
        .filter { $0.matches(recipient: recipient) }
        .map(\.rowId)
    }

    func placeholders(_ count: Int) -> String {
        Array(repeating: "?", count: count).joined(separator: ", ")
    }

}
