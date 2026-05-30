import Domain
import Foundation

package actor DomainEventStream: DomainEventStreaming {

    private typealias HeadUpdateStream = AsyncStream<UInt64>
    private typealias HeadUpdateContinuation = HeadUpdateStream.Continuation

    private struct Configuration: Sendable, Equatable {

        let maxSubscriptions: Int
        let replayCacheLimit: Int

        init(
            maxSubscriptions: Int = 100,
            replayCacheLimit: Int = 256
        ) {
            precondition(maxSubscriptions > 0, "maxSubscriptions must be positive")
            precondition(replayCacheLimit > 0, "replayCacheLimit must be positive")

            self.maxSubscriptions = maxSubscriptions
            self.replayCacheLimit = replayCacheLimit
        }

    }


    struct Stats: Sendable, Equatable {

        let subscribersActive: Int
        let subscribersMax: Int
        let publishedTotal: UInt64
        let rejectedSubscriptionsTotal: UInt64

    }


    private struct State {

        var subscribers: [UUID: HeadUpdateContinuation] = [:]
        var knownHeadSequence: UInt64?
        var publishedTotal: UInt64 = 0
        var rejectedSubscriptionsTotal: UInt64 = 0

    }


    private struct ReplayCache {

        private let limit: Int
        private var storage: [DomainEventEnvelope] = []

        init(limit: Int) {
            self.limit = limit
        }

        mutating func append(_ envelope: DomainEventEnvelope) {
            guard let newest = storage.last else {
                storage.append(envelope)
                return
            }

            if newest.sequence < envelope.sequence {
                storage.append(envelope)
            } else {
                insertSorted(envelope)
            }

            trimToLimit()
        }

        func cachedReplay(
            afterSequence: UInt64,
            throughSequence headSequence: UInt64
        ) -> [DomainEventEnvelope]? {
            guard
                let oldest = storage.first,
                let newest = storage.last
            else {
                return nil
            }

            guard headSequence <= newest.sequence else {
                return nil
            }

            let earliestReplayCursor = oldest.sequence > 0 ? oldest.sequence - 1 : 0

            guard afterSequence >= earliestReplayCursor else {
                return nil
            }

            return storage.filter {
                $0.sequence > afterSequence && $0.sequence <= headSequence
            }
        }

        private mutating func insertSorted(_ envelope: DomainEventEnvelope) {
            let insertIndex =
                storage.firstIndex { $0.sequence > envelope.sequence }
                ?? storage.endIndex

            storage.insert(envelope, at: insertIndex)
        }

        private mutating func trimToLimit() {
            if storage.count > limit {
                storage.removeFirst(storage.count - limit)
            }
        }

    }


    private enum ReplaySource: Sendable {

        case cache([DomainEventEnvelope])
        case log(DomainEventLog.Replay)

    }


    private struct RegisteredSubscriber {

        let afterSequence: UInt64
        let headUpdates: HeadUpdateStream

    }


    private struct ReplayEvents: AsyncSequence, Sendable {

        typealias Element = DomainEventEnvelope

        struct Iterator: AsyncIteratorProtocol {

            private var bufferedReplay: ArraySlice<DomainEventEnvelope> = []
            private var loggedReplayIterator: DomainEventLog.Replay.Iterator?

            fileprivate init(replaySource: ReplaySource) {
                switch replaySource {
                case .cache(let envelopes):
                    bufferedReplay = ArraySlice(envelopes)

                case .log(let replay):
                    loggedReplayIterator = replay.makeAsyncIterator()
                }
            }

            mutating func next() async throws -> DomainEventEnvelope? {
                if let envelope = bufferedReplay.popFirst() {
                    return envelope
                }

                guard var iterator = loggedReplayIterator else {
                    return nil
                }

                let envelope = try await iterator.next()
                loggedReplayIterator = iterator
                return envelope
            }

        }

        let replaySource: ReplaySource

        func makeAsyncIterator() -> Iterator {
            Iterator(replaySource: replaySource)
        }

    }


    private struct SubscriptionEvents: AsyncSequence, Sendable {

        typealias Element = DomainEventEnvelope

        struct Iterator: AsyncIteratorProtocol {

            private let eventStream: DomainEventStream
            private var headUpdates: HeadUpdateStream.Iterator
            private var bufferedReplay: ArraySlice<DomainEventEnvelope> = []
            private var loggedReplayIterator: DomainEventLog.Replay.Iterator?
            private var lastDeliveredSequence: UInt64

            fileprivate init(
                eventStream: DomainEventStream,
                headUpdates: HeadUpdateStream,
                afterSequence: UInt64
            ) {
                self.eventStream = eventStream
                self.headUpdates = headUpdates.makeAsyncIterator()
                self.lastDeliveredSequence = afterSequence
            }

            mutating func next() async throws -> DomainEventEnvelope? {
                while true {
                    if let envelope = bufferedReplay.popFirst() {
                        lastDeliveredSequence = envelope.sequence
                        return envelope
                    }

                    if var iterator = loggedReplayIterator {
                        if let envelope = try await iterator.next() {
                            lastDeliveredSequence = envelope.sequence
                            loggedReplayIterator = iterator
                            return envelope
                        }

                        loggedReplayIterator = nil
                    }

                    guard let headSequence = await headUpdates.next() else {
                        return nil
                    }

                    guard headSequence > lastDeliveredSequence else {
                        continue
                    }

                    switch try await eventStream.makeReplaySource(
                        afterSequence: lastDeliveredSequence,
                        throughSequence: headSequence
                    ) {
                    case .cache(let envelopes):
                        bufferedReplay = ArraySlice(envelopes)

                    case .log(let replay):
                        loggedReplayIterator = replay.makeAsyncIterator()
                    }
                }
            }

        }

        let eventStream: DomainEventStream
        let headUpdates: HeadUpdateStream
        let afterSequence: UInt64

        func makeAsyncIterator() -> Iterator {
            Iterator(
                eventStream: eventStream,
                headUpdates: headUpdates,
                afterSequence: afterSequence
            )
        }

    }


    private let eventLog: DomainEventLog
    private let configuration: Configuration
    private var state = State()
    private var replayCache: ReplayCache

    package init(eventLog: DomainEventLog) {
        self.eventLog = eventLog
        let configuration = Configuration()
        self.configuration = configuration
        self.replayCache = ReplayCache(limit: configuration.replayCacheLimit)
    }

    private var currentHead: UInt64 {
        state.knownHeadSequence ?? 0
    }

    package func publish(_ event: DomainEvent) async throws {
        try await publish([event])
    }

    package func publish(_ events: [DomainEvent]) async throws {
        guard !events.isEmpty else {
            return
        }

        let envelopes = try await eventLog.append(events)
        applyPublished(envelopes)
    }

    package func publish(
        _ events: [DomainEvent],
        cursor: NamedCursor
    ) async throws {
        let envelopes = try await eventLog.append(events, cursor: cursor)
        applyPublished(envelopes)
    }

    package func latestSequence() async throws -> UInt64 {
        try await ensureHeadLoaded()
        return currentHead
    }

    package func subscribe() async throws -> EventSubscription<DomainEventEnvelope> {
        try await ensureHeadLoaded()
        let subscriber = try registerSubscriber(afterSequence: currentHead)

        return EventSubscription(
            SubscriptionEvents(
                eventStream: self,
                headUpdates: subscriber.headUpdates,
                afterSequence: subscriber.afterSequence
            )
        )
    }

    package func replay(
        afterSequence: UInt64,
        throughSequence headSequence: UInt64
    ) async throws -> EventSubscription<DomainEventEnvelope> {
        try await ensureHeadLoaded()

        let replaySource = try await makeReplaySource(
            afterSequence: afterSequence,
            throughSequence: headSequence
        )

        return EventSubscription(ReplayEvents(replaySource: replaySource))
    }

    package func resume(afterSequence: UInt64) async throws -> EventSubscription<DomainEventEnvelope> {
        try await ensureHeadLoaded()
        let subscriber = try registerSubscriber(afterSequence: afterSequence)

        return EventSubscription(
            SubscriptionEvents(
                eventStream: self,
                headUpdates: subscriber.headUpdates,
                afterSequence: subscriber.afterSequence
            )
        )
    }

    package func loadCursor(name: String) async throws -> String? {
        try await eventLog.loadCursor(name: name)
    }

    package func saveCursor(_ cursor: NamedCursor) async throws {
        try await eventLog.saveCursor(cursor)
    }

    func stats() -> Stats {
        Stats(
            subscribersActive: state.subscribers.count,
            subscribersMax: configuration.maxSubscriptions,
            publishedTotal: state.publishedTotal,
            rejectedSubscriptionsTotal: state.rejectedSubscriptionsTotal
        )
    }

    private func applyPublished(_ envelopes: [DomainEventEnvelope]) {
        guard !envelopes.isEmpty else {
            return
        }

        state.publishedTotal &+= UInt64(envelopes.count)

        let batchHead = envelopes.map(\.sequence).max() ?? currentHead
        let newHead = max(currentHead, batchHead)
        state.knownHeadSequence = newHead

        for envelope in envelopes {
            replayCache.append(envelope)
        }

        notifySubscribers(ofHeadSequence: newHead)
    }

    private func ensureHeadLoaded() async throws {
        guard state.knownHeadSequence == nil else {
            return
        }

        let headSequence = try await eventLog.latestSequence()
        state.knownHeadSequence = max(currentHead, headSequence)
    }

    private func registerSubscriber(
        afterSequence: UInt64
    ) throws -> RegisteredSubscriber {
        guard state.subscribers.count < configuration.maxSubscriptions else {
            state.rejectedSubscriptionsTotal &+= 1

            throw DomainError(.serviceUnavailable, "Domain event stream subscriber capacity reached")
                .with("max_subscriptions", "\(configuration.maxSubscriptions)")
        }

        let (stream, continuation) = HeadUpdateStream.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        let id = UUID()
        state.subscribers[id] = continuation

        if afterSequence < currentHead {
            _ = continuation.yield(currentHead)
        }

        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }

        return RegisteredSubscriber(
            afterSequence: afterSequence,
            headUpdates: stream
        )
    }

    private func removeSubscriber(_ id: UUID) {
        state.subscribers.removeValue(forKey: id)
    }

    private func notifySubscribers(ofHeadSequence headSequence: UInt64) {
        var removedIDs: [UUID] = []

        for (id, continuation) in state.subscribers {
            switch continuation.yield(headSequence) {
            case .enqueued, .dropped:
                break

            case .terminated:
                removedIDs.append(id)

            @unknown default:
                removedIDs.append(id)
            }
        }

        for id in removedIDs {
            state.subscribers.removeValue(forKey: id)
        }
    }

    private func makeReplaySource(
        afterSequence: UInt64,
        throughSequence headSequence: UInt64
    ) async throws -> ReplaySource {
        if let cached = replayCache.cachedReplay(
            afterSequence: afterSequence,
            throughSequence: headSequence
        ) {
            return .cache(cached)
        }

        let replay = await eventLog.replay(
            afterSequence: afterSequence,
            throughSequence: headSequence
        )

        return .log(replay)
    }

}
