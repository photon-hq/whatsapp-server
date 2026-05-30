package protocol DomainEventStreaming: Sendable {

    func publish(_ event: DomainEvent) async throws

    func publish(_ events: [DomainEvent]) async throws

    func publish(
        _ events: [DomainEvent],
        cursor: NamedCursor
    ) async throws

    func latestSequence() async throws -> UInt64

    func subscribe() async throws -> EventSubscription<DomainEventEnvelope>

    func replay(
        afterSequence: UInt64,
        throughSequence: UInt64
    ) async throws -> EventSubscription<DomainEventEnvelope>

    func resume(afterSequence: UInt64) async throws -> EventSubscription<DomainEventEnvelope>

    func loadCursor(name: String) async throws -> String?

    func saveCursor(_ cursor: NamedCursor) async throws

}
