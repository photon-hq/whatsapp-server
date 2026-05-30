import Domain
import Foundation
import GRDB
import Logging

package actor ChatStorageEventObserver: EventObserving {

    private enum ClassifiedEvent {
        case emit(DomainEvent)
        case suppress
        case retry
    }

    private struct PersistedCursor: Codable {
        var lastRowId: Int64
        var pollRows: [String: PollSnapshot]
        var receiptRows: [String: ReceiptSnapshot]

        init(
            lastRowId: Int64,
            pollRows: [String: PollSnapshot] = [:],
            receiptRows: [String: ReceiptSnapshot] = [:]
        ) {
            self.lastRowId = lastRowId
            self.pollRows = pollRows
            self.receiptRows = receiptRows
        }
    }

    private struct PendingRowRetryState {
        let firstObservedAt: Date
        var retryCount: Int
    }

    private static let cursorName = "chat_storage_event_observer"

    private let database: ChatStorageDatabase
    private let walPath: String
    private let getPoll: any GetPoll
    private let eventStreaming: any DomainEventStreaming
    private let pollingInterval: Duration
    private let logger: Logger

    private var lastRowId: Int64 = 0
    private var pollRows: [String: PollSnapshot] = [:]
    private var receiptRows: [String: ReceiptSnapshot] = [:]
    private var isObserving = false
    private var observationTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var triggerContinuation: AsyncStream<Void>.Continuation?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var watcherFd: Int32 = -1
    private var hasLoggedWALMissing = false
    private var pendingRowRetries: [Int64: PendingRowRetryState] = [:]

    private let watcherQueue = DispatchQueue(label: "chatstorage.event-watcher")
    private let batchLimit = 100
    private let maxMaterializationRetryWindow: TimeInterval = 5

    struct PollSnapshot: Codable, Equatable, Sendable {
        let rowId: Int64
        let recipient: String
        let pollId: String
        let occurredAt: Date
        let isFromMe: Bool
        let poll: Poll
    }

    struct ReceiptSnapshot: Codable, Equatable, Sendable {
        let rowId: Int64
        let messageId: String
        let recipient: String
        let occurredAt: Date
        let isFromMe: Bool
        let receiptDigest: String
        let receiptHex: String
    }

    struct PollRootRow: Decodable, FetchableRecord, Sendable {
        let rowId: Int64
        let contactJid: String
        let partnerName: String?
        let stanzaId: String
        let isFromMe: Bool
        let messageDate: Double?
        let mediaMetadata: Data?
        let receiptInfo: Data?

        var uniqueKey: String {
            "\(contactJid)_\(stanzaId)_\(isFromMe ? 1 : 0)_0"
        }

        var recipient: String {
            ChatStorageRecipient(
                contactJid: contactJid,
                partnerName: partnerName
            ).publicValue
        }

        var occurredAt: Date {
            WhatsAppDate.fromStoredSeconds(messageDate) ?? Date()
        }

        var poll: Poll? {
            guard let parsed = WhatsAppPollSnapshotParser.parse(
                pollId: uniqueKey,
                metadata: mediaMetadata,
                receiptInfo: receiptInfo
            )
            else {
                return nil
            }

            return parsed
        }
    }

    struct ReceiptSnapshotRow: Decodable, FetchableRecord, Sendable {
        let rowId: Int64
        let contactJid: String
        let partnerName: String?
        let stanzaId: String
        let isFromMe: Bool
        let messageDate: Double?
        let receiptHex: String?

        var uniqueKey: String {
            "\(contactJid)_\(stanzaId)_\(isFromMe ? 1 : 0)_0"
        }

        var recipient: String {
            ChatStorageRecipient(
                contactJid: contactJid,
                partnerName: partnerName
            ).publicValue
        }

        var occurredAt: Date {
            WhatsAppDate.fromStoredSeconds(messageDate) ?? Date()
        }

        var snapshot: ReceiptSnapshot? {
            guard let receiptHex, !receiptHex.isEmpty else {
                return nil
            }

            return ReceiptSnapshot(
                rowId: rowId,
                messageId: uniqueKey,
                recipient: recipient,
                occurredAt: occurredAt,
                isFromMe: isFromMe,
                receiptDigest: SHA256Hex.string(receiptHex),
                receiptHex: receiptHex
            )
        }
    }

    package init(
        database: ChatStorageDatabase,
        chatStoragePath: String,
        getPoll: any GetPoll,
        eventStreaming: any DomainEventStreaming,
        pollingInterval: Duration,
        logger: Logger = Logger(label: "ChatStorageEventObserver")
    ) {
        self.database = database
        self.walPath = "\(chatStoragePath)-wal"
        self.getPoll = getPoll
        self.eventStreaming = eventStreaming
        self.pollingInterval = pollingInterval
        self.logger = logger
    }

    package func startObserving() async throws {
        guard !isObserving else {
            return
        }

        isObserving = true
        pendingRowRetries.removeAll()

        do {
            if let cursor = try await loadPersistedCursor() {
                let maxRowId = try await currentMaxRowId()

                guard cursor.lastRowId <= maxRowId else {
                    throw DomainError(.internalError, "Observer cursor ahead of ChatStorage.sqlite")
                        .with("persisted_row_id", String(cursor.lastRowId))
                        .with("current_max_row_id", String(maxRowId))
                }

                lastRowId = cursor.lastRowId
                pollRows = cursor.pollRows
                receiptRows = cursor.receiptRows
            } else {
                lastRowId = try await currentMaxRowId()
                pollRows = try await loadPollSnapshots()
                receiptRows = try await loadReceiptSnapshots()

                try await eventStreaming.saveCursor(
                    try makePersistedCursor()
                )
            }
        } catch {
            isObserving = false
            throw error
        }

        let (stream, continuation) = AsyncStream<Void>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        triggerContinuation = continuation

        pollingTask = Task { [weak self, pollingInterval] in
            await self?.maintainWALWatcher()

            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval)

                guard !Task.isCancelled else {
                    break
                }

                await self?.maintainWALWatcher()
                continuation.yield(())
            }
        }

        observationTask = Task { [weak self] in
            for await _ in stream {
                guard let self else {
                    break
                }

                guard await self.isObserving else {
                    break
                }

                await self.drainEvents()
            }
        }

        continuation.yield(())
        logger.info("Observation started")
    }

    package func stopObserving() async throws {
        isObserving = false

        let observationTask = observationTask
        let pollingTask = pollingTask

        observationTask?.cancel()
        pollingTask?.cancel()

        detachWALWatcher()

        triggerContinuation?.finish()
        triggerContinuation = nil

        await observationTask?.value
        await pollingTask?.value

        self.observationTask = nil
        self.pollingTask = nil

        logger.info("Observation stopped")
    }

    private func drainEvents() async {
        do {
            var hasMore = true

            while hasMore && isObserving && !Task.isCancelled {
                hasMore = try await processBatch()
            }

            guard isObserving, !Task.isCancelled else {
                return
            }

            try await publishStateChanges()
        } catch is CancellationError {
        } catch {
            logger.error("Failed to observe ChatStorage.sqlite", metadata: ["error": "\(error)"])
        }
    }

    private func processBatch() async throws -> Bool {
        let cursor = lastRowId

        let records = try await database.read { [batchLimit] db in
            try ChatStorageEventRecord.fetchAll(
                db,
                sql: """
                    SELECT
                        m.Z_PK AS rowId,
                        c.ZCONTACTJID AS contactJid,
                        c.ZPARTNERNAME AS partnerName,
                        m.ZSTANZAID AS stanzaId,
                        m.ZTEXT AS text,
                        m.ZISFROMME AS isFromMe,
                        m.ZMESSAGETYPE AS messageType,
                        m.ZMESSAGEDATE AS messageDate,
                        COALESCE(pc.ZCONTACTJID, qpc.ZCONTACTJID) AS parentContactJid,
                        COALESCE(p.ZSTANZAID, qp.ZSTANZAID) AS parentStanzaId,
                        COALESCE(p.ZISFROMME, qp.ZISFROMME) AS parentIsFromMe,
                        media.ZMEDIALOCALPATH AS mediaLocalPath,
                        media.ZFILESIZE AS mediaFileSize,
                        media.ZTITLE AS mediaTitle,
                        media.ZVCARDNAME AS mediaVCardName,
                        media.ZLATITUDE AS mediaLatitude,
                        media.ZLONGITUDE AS mediaLongitude,
                        media.ZMETADATA AS mediaMetadata,
                        info.ZRECEIPTINFO AS receiptInfo
                    FROM ZWAMESSAGE m
                    JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
                    LEFT JOIN ZWAMESSAGE p ON p.Z_PK = m.ZPARENTMESSAGE
                    LEFT JOIN ZWACHATSESSION pc ON pc.Z_PK = p.ZCHATSESSION
                    LEFT JOIN ZWAMEDIAITEM media ON media.Z_PK = m.ZMEDIAITEM
                    LEFT JOIN ZWAMESSAGEINFO info ON info.Z_PK = m.ZMESSAGEINFO
                    LEFT JOIN ZWAMESSAGE qp
                      ON p.Z_PK IS NULL
                     AND qp.ZCHATSESSION = m.ZCHATSESSION
                     AND qp.Z_PK != m.Z_PK
                     AND qp.ZSTANZAID IS NOT NULL
                     AND qp.ZSTANZAID != ''
                     AND media.ZMETADATA IS NOT NULL
                     AND instr(media.ZMETADATA, CAST(qp.ZSTANZAID AS BLOB)) > 0
                    LEFT JOIN ZWACHATSESSION qpc ON qpc.Z_PK = qp.ZCHATSESSION
                    WHERE m.Z_PK > ?
                      AND m.ZSTANZAID IS NOT NULL
                      AND m.ZSTANZAID != ''
                    ORDER BY m.Z_PK ASC
                    LIMIT ?
                    """,
                arguments: [cursor, batchLimit]
            )
        }

        for record in records {
            guard isObserving, !Task.isCancelled else {
                break
            }

            switch try await classify(record) {
            case .emit(let event):
                try await eventStreaming.publish(
                    [event],
                    cursor: try makePersistedCursor(lastRowId: record.rowId)
                )
                pendingRowRetries.removeValue(forKey: record.rowId)

            case .suppress:
                try await eventStreaming.publish(
                    [],
                    cursor: try makePersistedCursor(lastRowId: record.rowId)
                )
                pendingRowRetries.removeValue(forKey: record.rowId)

            case .retry:
                guard shouldKeepRetrying(
                    rowId: record.rowId,
                    message: "ChatStorage row is waiting for related state",
                    expiredMessage: "ChatStorage row still missing related state after retries",
                    metadata: [
                        "row_id": "\(record.rowId)",
                        "stanza_id": "\(record.stanzaId)",
                        "message_type": "\(record.messageType)",
                    ]
                ) else {
                    try await eventStreaming.publish(
                        [],
                        cursor: try makePersistedCursor(lastRowId: record.rowId)
                    )
                    pendingRowRetries.removeValue(forKey: record.rowId)
                    lastRowId = record.rowId

                    continue
                }

                return false
            }

            lastRowId = record.rowId
        }

        return records.count == batchLimit
    }

    private func classify(_ record: ChatStorageEventRecord) async throws -> ClassifiedEvent {
        if record.isPollMessage {
            return try await classifyPoll(record)
        }

        if let attachment = record.attachment {
            return .emit(.message(.changed(MessageChangeEvent(
                recipient: record.recipient,
                sourceRowId: record.rowId,
                occurredAt: record.occurredAt,
                isFromMe: record.isFromMe,
                change: .attachment(attachment)
            ))))
        }

        if let text = record.messageText {
            return .emit(.message(.changed(MessageChangeEvent(
                recipient: record.recipient,
                sourceRowId: record.rowId,
                occurredAt: record.occurredAt,
                isFromMe: record.isFromMe,
                change: .text(text)
            ))))
        }

        return .suppress
    }

    private func classifyPoll(_ record: ChatStorageEventRecord) async throws -> ClassifiedEvent {
        let poll: Poll

        if let parsedPoll = record.poll {
            poll = parsedPoll
        } else {
            do {
                poll = try await getPoll.getPoll(pollId: record.uniqueKey)
            } catch {
                logger.warning(
                    "Poll row found but poll snapshot is unavailable",
                    metadata: [
                        "row_id": "\(record.rowId)",
                        "poll_id": "\(record.uniqueKey)",
                        "error": "\(error)",
                    ]
                )

                return .retry
            }
        }

        return .emit(.poll(.changed(PollChangeEvent(
            recipient: record.recipient,
            pollId: record.uniqueKey,
            sourceRowId: record.rowId,
            occurredAt: record.occurredAt,
            isFromMe: record.isFromMe,
            change: .created(poll)
        ))))
    }

    private func publishStateChanges() async throws {
        let nextPollRows = try await loadPollSnapshots()
        let nextReceiptRows = try await loadReceiptSnapshots()
        let occurredAt = Date()
        let cursor = try makePersistedCursor(
            pollRows: nextPollRows,
            receiptRows: nextReceiptRows
        )

        let events = Self.pollEvents(
            from: pollRows,
            to: nextPollRows,
            occurredAt: occurredAt
        )
            + Self.receiptEvents(
                from: receiptRows,
                to: nextReceiptRows,
                pollRootIds: Set(pollRows.keys).union(nextPollRows.keys),
                occurredAt: occurredAt
            )

        guard !events.isEmpty else {
            try await eventStreaming.saveCursor(cursor)

            pollRows = nextPollRows
            receiptRows = nextReceiptRows

            return
        }

        try await eventStreaming.publish(
            events,
            cursor: cursor
        )

        pollRows = nextPollRows
        receiptRows = nextReceiptRows
    }

    private func loadPollSnapshots() async throws -> [String: PollSnapshot] {
        let rows = try await database.read { db in
            try PollRootRow.fetchAll(
                db,
                sql: """
                    SELECT
                        m.Z_PK AS rowId,
                        c.ZCONTACTJID AS contactJid,
                        c.ZPARTNERNAME AS partnerName,
                        m.ZSTANZAID AS stanzaId,
                        m.ZISFROMME AS isFromMe,
                        m.ZMESSAGEDATE AS messageDate,
                        media.ZMETADATA AS mediaMetadata,
                        info.ZRECEIPTINFO AS receiptInfo
                    FROM ZWAMESSAGE m
                    JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
                    LEFT JOIN ZWAMEDIAITEM media ON media.Z_PK = m.ZMEDIAITEM
                    LEFT JOIN ZWAMESSAGEINFO info ON info.Z_PK = m.ZMESSAGEINFO
                    WHERE m.ZMESSAGETYPE IN (13, 46)
                      AND m.ZSTANZAID IS NOT NULL
                      AND m.ZSTANZAID != ''
                    ORDER BY m.Z_PK ASC
                    """
            )
        }

        var snapshots: [String: PollSnapshot] = [:]
        for row in rows {
            do {
                let poll: Poll
                if let parsedPoll = row.poll {
                    poll = parsedPoll
                } else {
                    poll = try await getPoll.getPoll(pollId: row.uniqueKey)
                }
                snapshots[row.uniqueKey] = PollSnapshot(
                    rowId: row.rowId,
                    recipient: row.recipient,
                    pollId: row.uniqueKey,
                    occurredAt: row.occurredAt,
                    isFromMe: row.isFromMe,
                    poll: poll
                )
            } catch {
                logger.warning(
                    "Poll root row found but poll snapshot is unavailable",
                    metadata: [
                        "row_id": "\(row.rowId)",
                        "poll_id": "\(row.uniqueKey)",
                        "error": "\(error)",
                    ]
                )
            }
        }

        return snapshots
    }

    private func loadReceiptSnapshots() async throws -> [String: ReceiptSnapshot] {
        let rows = try await database.read { db in
            try ReceiptSnapshotRow.fetchAll(
                db,
                sql: """
                    SELECT
                        m.Z_PK AS rowId,
                        c.ZCONTACTJID AS contactJid,
                        c.ZPARTNERNAME AS partnerName,
                        m.ZSTANZAID AS stanzaId,
                        m.ZISFROMME AS isFromMe,
                        m.ZMESSAGEDATE AS messageDate,
                        hex(info.ZRECEIPTINFO) AS receiptHex
                    FROM ZWAMESSAGE m
                    JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
                    JOIN ZWAMESSAGEINFO info ON info.Z_PK = m.ZMESSAGEINFO
                    WHERE m.ZSTANZAID IS NOT NULL
                      AND m.ZSTANZAID != ''
                      AND info.ZRECEIPTINFO IS NOT NULL
                      AND length(info.ZRECEIPTINFO) > 0
                    ORDER BY m.Z_PK ASC
                    """
            )
        }

        return Dictionary(rows.compactMap { row in
            row.snapshot.map { ($0.messageId, $0) }
        }) { _, new in new }
    }

    static func pollEvents(
        from previous: [String: PollSnapshot],
        to current: [String: PollSnapshot],
        occurredAt: Date
    ) -> [DomainEvent] {
        current.keys.sorted().flatMap { key -> [DomainEvent] in
            guard let row = current[key],
                  let old = previous[key]
            else {
                return []
            }

            guard let change = pollChange(from: old.poll, to: row.poll) else {
                return []
            }

            return [.poll(.changed(PollChangeEvent(
                recipient: row.recipient,
                pollId: row.pollId,
                sourceRowId: row.rowId,
                occurredAt: occurredAt,
                isFromMe: row.isFromMe,
                change: change
            )))]
        }
    }

    static func pollChange(from old: Poll, to new: Poll) -> PollChange? {
        guard old != new else {
            return nil
        }

        if old.choices.map(\.text) != new.choices.map(\.text) {
            return .choicesChanged(new)
        }

        if old.choices.map(\.voteCount) != new.choices.map(\.voteCount) {
            return .voteChanged(new)
        }

        return .updated(new)
    }

    static func receiptEvents(
        from previous: [String: ReceiptSnapshot],
        to current: [String: ReceiptSnapshot],
        pollRootIds: Set<String>,
        occurredAt: Date
    ) -> [DomainEvent] {
        current.keys.sorted().flatMap { key -> [DomainEvent] in
            guard !pollRootIds.contains(key) else {
                return []
            }

            guard let row = current[key],
                  let old = previous[key],
                  row.receiptDigest != old.receiptDigest
            else {
                return []
            }

            guard !isOnlyDeliveryStatusChange(from: old.receiptHex, to: row.receiptHex) else {
                return []
            }

            guard let change = reactionChange(
                from: old.receiptHex,
                to: row.receiptHex,
                messageId: row.messageId
            ) else {
                return []
            }

            return [.message(.changed(MessageChangeEvent(
                recipient: row.recipient,
                sourceRowId: row.rowId,
                occurredAt: occurredAt,
                isFromMe: row.isFromMe,
                change: change
            )))]
        }
    }

    static func isOnlyDeliveryStatusChange(from oldHex: String, to newHex: String) -> Bool {
        // Delivery/read receipts often rewrite compact protobuf fields without
        // carrying reaction or poll payload tags. Those are intentionally left
        // out of the message event stream until a stable receipt model exists.
        !oldHex.contains("3A") && !newHex.contains("3A") && !oldHex.contains("42") && !newHex.contains("42")
    }

    static func reactionChange(from oldHex: String, to newHex: String, messageId: String) -> MessageChange? {
        guard oldHex.contains("3A") || newHex.contains("3A") else {
            return nil
        }

        let oldEmoji = ReceiptInfoParser.lastEmoji(inHex: oldHex)
        let newEmoji = ReceiptInfoParser.lastEmoji(inHex: newHex)
        guard oldEmoji != newEmoji else {
            return nil
        }

        return .reaction(MessageReaction(
            messageId: messageId,
            emoji: newEmoji,
            actorJid: ReceiptInfoParser.lastLid(inHex: newHex) ?? ReceiptInfoParser.lastLid(inHex: oldHex),
            reactionId: ReceiptInfoParser.lastStanzaId(inHex: newHex)
                ?? ReceiptInfoParser.lastStanzaId(inHex: oldHex)
        ))
    }

    private func maintainWALWatcher() async {
        if dispatchSource != nil {
            var fdStat = stat()
            var pathStat = stat()
            let sameFile = fstat(watcherFd, &fdStat) == 0
                && stat(walPath, &pathStat) == 0
                && fdStat.st_ino == pathStat.st_ino

            if sameFile {
                return
            }

            detachWALWatcher()
        }

        guard let triggerContinuation else {
            return
        }

        watcherFd = open(walPath, O_EVTONLY)

        guard watcherFd >= 0 else {
            if !hasLoggedWALMissing {
                logger.warning("ChatStorage WAL not found, using polling only")
                hasLoggedWALMissing = true
            }

            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watcherFd,
            eventMask: [.write, .extend],
            queue: watcherQueue
        )

        source.setEventHandler {
            triggerContinuation.yield(())
        }
        source.resume()

        dispatchSource = source
        hasLoggedWALMissing = false
        logger.info("ChatStorage WAL monitoring started")
    }

    private func detachWALWatcher() {
        guard let source = dispatchSource else {
            watcherFd = -1
            return
        }

        dispatchSource = nil

        if watcherFd >= 0 {
            close(watcherFd)
        }
        watcherFd = -1

        source.setEventHandler {}
        source.cancel()
    }

    private func currentMaxRowId() async throws -> Int64 {
        try await database.read { db in
            try Int64.fetchOne(db, sql: "SELECT MAX(Z_PK) FROM ZWAMESSAGE") ?? 0
        }
    }

    private func loadPersistedCursor() async throws -> PersistedCursor? {
        let raw = try await eventStreaming.loadCursor(name: Self.cursorName)

        guard let raw else {
            return nil
        }

        guard let data = raw.data(using: .utf8) else {
            logger.warning("Observer cursor is not UTF-8; rebuilding ChatStorage snapshots")
            return nil
        }

        do {
            return try JSONDecoder().decode(PersistedCursor.self, from: data)
        } catch {
            logger.warning(
                "Observer cursor is stale; rebuilding ChatStorage snapshots",
                metadata: ["error": "\(error)"]
            )
            return nil
        }
    }

    private func makePersistedCursor(
        lastRowId: Int64? = nil,
        pollRows: [String: PollSnapshot]? = nil,
        receiptRows: [String: ReceiptSnapshot]? = nil
    ) throws -> NamedCursor {
        let data = try JSONEncoder().encode(PersistedCursor(
            lastRowId: lastRowId ?? self.lastRowId,
            pollRows: pollRows ?? self.pollRows,
            receiptRows: receiptRows ?? self.receiptRows
        ))

        guard let value = String(data: data, encoding: .utf8) else {
            throw DomainError(.internalError, "Observer cursor encode produced non-UTF8")
        }

        return NamedCursor(name: Self.cursorName, value: value)
    }

    private func shouldKeepRetrying(
        rowId: Int64,
        message: String,
        expiredMessage: String,
        metadata: Logger.Metadata
    ) -> Bool {
        let now = Date()
        var state = pendingRowRetries[rowId]
            ?? PendingRowRetryState(
                firstObservedAt: now,
                retryCount: 0
            )

        state.retryCount += 1
        pendingRowRetries[rowId] = state

        let elapsed = now.timeIntervalSince(state.firstObservedAt)
        let retryMetadata = metadata.merging([
            "retry": "\(state.retryCount)",
            "elapsed_ms": "\(Int(elapsed * 1_000))",
        ]) { current, _ in current }

        guard elapsed < maxMaterializationRetryWindow else {
            logger.warning(
                Logger.Message(stringLiteral: expiredMessage),
                metadata: retryMetadata
            )

            return false
        }

        logger.warning(
            Logger.Message(stringLiteral: message),
            metadata: retryMetadata
        )

        return true
    }

}
