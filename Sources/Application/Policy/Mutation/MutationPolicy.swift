import Domain

package protocol MutationPolicy: Sendable {

    func execute<T: Sendable>(
        clientMessageId: String?,
        _ body: @Sendable () async throws -> T
    ) async throws -> T
}


package protocol MutationPolicyStep: Sendable {

    func acquire(clientMessageId: String?) async throws -> MutationReservation
}


package struct MutationReservation: Sendable {

    package let confirm: @Sendable () async -> Void
    package let release: @Sendable () async -> Void

    package init(
        confirm: @escaping @Sendable () async -> Void,
        release: @escaping @Sendable () async -> Void
    ) {
        self.confirm = confirm
        self.release = release
    }

    package static let noop = MutationReservation(confirm: {}, release: {})
}


package struct MutationPolicyPipeline: MutationPolicy {

    private let steps: [any MutationPolicyStep]

    package init(steps: [any MutationPolicyStep]) {
        self.steps = steps
    }

    package func execute<T: Sendable>(
        clientMessageId: String?,
        _ body: @Sendable () async throws -> T
    ) async throws -> T {
        var reservations: [MutationReservation] = []
        reservations.reserveCapacity(steps.count)

        do {
            for step in steps {
                reservations.append(try await step.acquire(clientMessageId: clientMessageId))
            }
        } catch {
            for reservation in reservations.reversed() {
                await reservation.release()
            }
            throw error
        }

        do {
            let result = try await body()
            for reservation in reservations {
                await reservation.confirm()
            }
            return result
        } catch {
            for reservation in reservations.reversed() {
                await reservation.release()
            }
            throw error
        }
    }
}


package struct DeduplicateClientMessageIdStep: MutationPolicyStep {

    private let checker: any DeduplicationChecking

    package init(checker: any DeduplicationChecking) {
        self.checker = checker
    }

    package func acquire(clientMessageId: String?) async throws -> MutationReservation {
        guard let clientMessageId else {
            return .noop
        }

        guard await checker.reserve(clientMessageId: clientMessageId) else {
            throw DomainError(
                .duplicateMessage,
                "Operation already processed with this client message ID"
            )
                .with("client_message_id", clientMessageId)
        }

        return MutationReservation(
            confirm: { [checker] in
                await checker.confirm(clientMessageId: clientMessageId)
            },
            release: { [checker] in
                await checker.release(clientMessageId: clientMessageId)
            }
        )
    }
}
