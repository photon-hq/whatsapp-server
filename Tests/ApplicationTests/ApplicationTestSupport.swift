import XCTest
@testable import Application
@testable import Domain

func applicationTestMutationPolicy(
    checker: (any DeduplicationChecking)?
) -> MutationPolicyPipeline {
    MutationPolicyPipeline(
        steps: [
            DeduplicateClientMessageIdStep(checker: checker ?? TestDeduplicationChecker()),
        ]
    )
}

actor TestEventStream: DomainEventStreaming {

    func publish(_ event: DomainEvent) async throws {}

    func publish(_ events: [DomainEvent]) async throws {}

    func publish(
        _ events: [DomainEvent],
        cursor: NamedCursor
    ) async throws {}

    func latestSequence() async throws -> UInt64 {
        0
    }

    func subscribe() async throws -> EventSubscription<DomainEventEnvelope> {
        EventSubscription(
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        )
    }

    func replay(
        afterSequence: UInt64,
        throughSequence: UInt64
    ) async throws -> EventSubscription<DomainEventEnvelope> {
        EventSubscription(
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        )
    }

    func resume(afterSequence: UInt64) async throws -> EventSubscription<DomainEventEnvelope> {
        EventSubscription(
            AsyncThrowingStream { continuation in
                continuation.finish()
            }
        )
    }

    func loadCursor(name: String) async throws -> String? {
        nil
    }

    func saveCursor(_ cursor: NamedCursor) async throws {}

}

actor TestDeduplicationChecker: DeduplicationChecking {

    private var seen = Set<String>()

    func reserve(clientMessageId: String) async -> Bool {
        seen.insert(clientMessageId).inserted
    }

    func confirm(clientMessageId: String) async {
    }

    func release(clientMessageId: String) async {
        seen.remove(clientMessageId)
    }

}

func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
    }
}
