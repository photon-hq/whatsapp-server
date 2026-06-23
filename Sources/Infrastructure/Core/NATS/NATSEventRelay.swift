import Domain
import Foundation
import Logging
import Nats

package protocol NATSPublishing: Sendable {

    func connect() async throws
    func publish(_ payload: Data, subject: String) async throws
    func close() async

}


package final class NATSClientPublisher: NATSPublishing, @unchecked Sendable {

    private let client: NatsClient
    private var isConnected = false

    package init(url: URL) {
        client = NatsClientOptions()
            .url(url)
            .build()
    }

    package func connect() async throws {
        guard !isConnected else {
            return
        }

        try await client.connect()
        isConnected = true
    }

    package func publish(_ payload: Data, subject: String) async throws {
        try await client.publish(payload, subject: subject)
    }

    package func close() async {
        guard isConnected else {
            return
        }

        do {
            try await client.close()
        } catch {
            // Closing during reconnect/shutdown can race with the client state.
        }

        isConnected = false
    }

}


package actor NATSEventRelay {

    package struct Configuration: Sendable, Equatable {

        package let url: URL
        package let subjectPrefix: String
        package let cursorName: String
        package let deviceID: String?
        package let retryDelay: Duration

        package init(
            url: URL,
            subjectPrefix: String,
            cursorName: String,
            deviceID: String? = nil,
            retryDelay: Duration = .seconds(2)
        ) {
            self.url = url
            self.subjectPrefix = subjectPrefix
            self.cursorName = cursorName
            self.deviceID = deviceID
            self.retryDelay = retryDelay
        }

    }


    private let configuration: Configuration
    private let eventStreaming: any DomainEventStreaming
    private let publisher: any NATSPublishing
    private let mapper: NATSEventPayloadMapper
    private let logger: Logger

    private var relayTask: Task<Void, Never>?

    package init(
        configuration: Configuration,
        eventStreaming: any DomainEventStreaming,
        publisher: (any NATSPublishing)? = nil,
        logger: Logger = Logger(label: "NATSEventRelay")
    ) {
        self.configuration = configuration
        self.eventStreaming = eventStreaming
        self.publisher = publisher ?? NATSClientPublisher(url: configuration.url)
        self.mapper = NATSEventPayloadMapper(
            subjectPrefix: configuration.subjectPrefix,
            deviceID: configuration.deviceID
        )
        self.logger = logger
    }

    package func start() {
        guard relayTask == nil else {
            return
        }

        relayTask = Task { [weak self] in
            await self?.run()
        }
    }

    package func stop() async {
        let task = relayTask
        relayTask = nil
        task?.cancel()
        await task?.value
        await publisher.close()
    }

    package func publishAvailableEventsOnce() async throws -> UInt64 {
        let afterSequence = try await loadCursorSequence()
        let headSequence = try await eventStreaming.latestSequence()

        guard headSequence > afterSequence else {
            return 0
        }

        let replay = try await eventStreaming.replay(
            afterSequence: afterSequence,
            throughSequence: headSequence
        )

        var published: UInt64 = 0
        for try await envelope in replay {
            try Task.checkCancellation()
            try await publish(envelope)
            published += 1
        }

        return published
    }

    private func run() async {
        while !Task.isCancelled {
            do {
                try await publisher.connect()
                logger.info("Connected to NATS", metadata: [
                    "url": "\(configuration.url.absoluteString)",
                    "subject_prefix": "\(configuration.subjectPrefix)",
                ])

                _ = try await publishAvailableEventsOnce()
                try await publishLiveEvents()
            } catch is CancellationError {
                break
            } catch {
                logger.error("NATS relay failed", metadata: ["error": "\(error)"])
                await publisher.close()
                await sleepBeforeRetry()
            }
        }
    }

    private func publishLiveEvents() async throws {
        let afterSequence = try await loadCursorSequence()
        let subscription = try await eventStreaming.resume(afterSequence: afterSequence)

        for try await envelope in subscription {
            try Task.checkCancellation()
            try await publish(envelope)
        }
    }

    private func publish(_ envelope: DomainEventEnvelope) async throws {
        let publication = try mapper.publication(for: envelope)

        try await publisher.publish(
            publication.payload,
            subject: publication.subject
        )

        try await eventStreaming.saveCursor(
            NamedCursor(
                name: configuration.cursorName,
                value: String(envelope.sequence)
            )
        )
    }

    private func loadCursorSequence() async throws -> UInt64 {
        guard let value = try await eventStreaming.loadCursor(name: configuration.cursorName) else {
            return 0
        }

        guard let sequence = UInt64(value) else {
            throw DomainError(.internalError, "NATS publisher cursor is not a valid sequence")
                .with("cursor", configuration.cursorName)
                .with("value", value)
        }

        return sequence
    }

    private func sleepBeforeRetry() async {
        do {
            try await Task.sleep(for: configuration.retryDelay)
        } catch {
        }
    }

}
