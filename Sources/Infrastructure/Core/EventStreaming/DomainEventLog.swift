import Domain
import Foundation
import GRDB

package actor DomainEventLog {

    struct Replay: AsyncSequence, Sendable {

        typealias Element = DomainEventEnvelope

        struct Iterator: AsyncIteratorProtocol {

            private let eventLog: DomainEventLog
            private let headSequence: UInt64
            private var lastDeliveredSequence: UInt64
            private var bufferedEnvelopes: ArraySlice<DomainEventEnvelope> = []

            fileprivate init(
                eventLog: DomainEventLog,
                afterSequence: UInt64,
                headSequence: UInt64
            ) {
                self.eventLog = eventLog
                self.headSequence = headSequence
                self.lastDeliveredSequence = afterSequence
            }

            mutating func next() async throws -> DomainEventEnvelope? {
                if let envelope = drainBufferedEnvelope() {
                    return envelope
                }

                guard lastDeliveredSequence < headSequence else {
                    return nil
                }

                let batch = try await eventLog.readReplayBatch(
                    afterSequence: lastDeliveredSequence,
                    headSequence: headSequence
                )

                guard !batch.isEmpty else {
                    lastDeliveredSequence = headSequence
                    return nil
                }

                bufferedEnvelopes = ArraySlice(batch)
                return drainBufferedEnvelope()
            }

            private mutating func drainBufferedEnvelope() -> DomainEventEnvelope? {
                guard let envelope = bufferedEnvelopes.popFirst() else {
                    return nil
                }

                lastDeliveredSequence = envelope.sequence
                return envelope
            }

        }

        let headSequence: UInt64

        private let eventLog: DomainEventLog
        private let afterSequence: UInt64

        fileprivate init(
            eventLog: DomainEventLog,
            afterSequence: UInt64,
            headSequence: UInt64
        ) {
            self.eventLog = eventLog
            self.afterSequence = afterSequence
            self.headSequence = headSequence
        }

        func makeAsyncIterator() -> Iterator {
            Iterator(
                eventLog: eventLog,
                afterSequence: afterSequence,
                headSequence: headSequence
            )
        }

    }


    private static let replayBatchSize = 100


    private struct PersistedRow {

        let sequence: UInt64
        let recordedAt: Date
        let payload: Data

    }


    private struct EncodedEvent: Sendable {

        let recordedAt: Date
        let event: DomainEvent
        let payload: Data

    }

    private let database: ServerDatabase

    package init(database: ServerDatabase) {
        self.database = database
    }

    func append(_ event: DomainEvent) async throws -> DomainEventEnvelope {
        guard let envelope = try await append([event]).first else {
            throw DomainError(.internalError, "Failed to append domain event")
        }

        return envelope
    }

    func append(
        _ events: [DomainEvent],
        cursor: NamedCursor? = nil
    ) async throws -> [DomainEventEnvelope] {
        if events.isEmpty, cursor == nil {
            return []
        }

        var encoded: [EncodedEvent] = []
        encoded.reserveCapacity(events.count)

        for event in events {
            do {
                encoded.append(
                    EncodedEvent(
                        recordedAt: Date(),
                        event: event,
                        payload: try EventLogCodec.encode(event)
                    )
                )
            } catch {
                throw DomainError(.internalError, "Failed to encode domain event")
                    .with("event_type", event.label)
            }
        }

        let encodedEvents = encoded

        return try await database.write { db in
            var envelopes: [DomainEventEnvelope] = []

            for item in encodedEvents {
                try db.execute(
                    sql: "INSERT INTO event_log (recorded_at, payload) VALUES (?, ?)",
                    arguments: [item.recordedAt, item.payload]
                )

                envelopes.append(
                    DomainEventEnvelope(
                        sequence: UInt64(db.lastInsertedRowID),
                        recordedAt: item.recordedAt,
                        event: item.event
                    )
                )
            }

            if let cursor {
                try Self.upsertCursor(db: db, cursor: cursor)
            }

            return envelopes
        }
    }

    func loadCursor(name: String) async throws -> String? {
        try await database.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT value FROM persistent_cursors WHERE name = ?",
                arguments: [name]
            )
        }
    }

    func saveCursor(_ cursor: NamedCursor) async throws {
        try await database.write { db in
            try Self.upsertCursor(db: db, cursor: cursor)
        }
    }

    func latestSequence() async throws -> UInt64 {
        try await database.read { db in
            UInt64(try Int64.fetchOne(db, sql: "SELECT MAX(sequence) FROM event_log") ?? 0)
        }
    }

    func replay(afterSequence: UInt64) async throws -> Replay {
        let headSequence = try await latestSequence()

        return replay(
            afterSequence: afterSequence,
            throughSequence: headSequence
        )
    }

    func replay(
        afterSequence: UInt64,
        throughSequence headSequence: UInt64
    ) -> Replay {
        Replay(
            eventLog: self,
            afterSequence: afterSequence,
            headSequence: headSequence
        )
    }

    private func readReplayBatch(
        afterSequence: UInt64,
        headSequence: UInt64
    ) async throws -> [DomainEventEnvelope] {
        let rows = try await database.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT sequence, recorded_at, payload
                    FROM event_log
                    WHERE sequence > ? AND sequence <= ?
                    ORDER BY sequence ASC
                    LIMIT ?
                    """,
                arguments: [
                    Int64(afterSequence),
                    Int64(headSequence),
                    Self.replayBatchSize,
                ]
            ).map { row in
                PersistedRow(
                    sequence: UInt64(row["sequence"] as Int64),
                    recordedAt: row["recorded_at"],
                    payload: row["payload"]
                )
            }
        }

        return try rows.map { row in
            let event: DomainEvent

            do {
                event = try EventLogCodec.decode(row.payload)
            } catch {
                throw DomainError(.internalError, "Failed to decode persisted domain event")
                    .with("sequence", "\(row.sequence)")
            }

            return DomainEventEnvelope(
                sequence: row.sequence,
                recordedAt: row.recordedAt,
                event: event
            )
        }
    }

    private static func upsertCursor(
        db: Database,
        cursor: NamedCursor
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO persistent_cursors (name, value, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(name) DO UPDATE SET
                    value = excluded.value,
                    updated_at = excluded.updated_at
                """,
            arguments: [cursor.name, cursor.value, Date()]
        )
    }

}
