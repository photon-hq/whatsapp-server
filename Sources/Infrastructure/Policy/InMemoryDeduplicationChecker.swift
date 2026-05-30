import Domain
import Foundation

package actor InMemoryDeduplicationChecker: DeduplicationChecking {

    private var confirmed: [String: Date] = [:]
    private var reserved: [String: Date] = [:]

    private let ttl: TimeInterval
    private let reservedTTL: TimeInterval

    private var opsSinceEviction = 0

    private static let evictionFrequency = 128
    private static let minimumReservedTTLSeconds: TimeInterval = 300

    package init(
        ttl: TimeInterval,
        reservedTTL: TimeInterval? = nil
    ) {
        self.ttl = ttl
        self.reservedTTL = reservedTTL ?? max(ttl, Self.minimumReservedTTLSeconds)
    }

    package func reserve(clientMessageId: String) async -> Bool {
        maybeEvictAll()

        if reserved[clientMessageId] != nil {
            return false
        }

        if let storedAt = confirmed[clientMessageId] {
            if Date().timeIntervalSince(storedAt) < ttl {
                return false
            }

            confirmed.removeValue(forKey: clientMessageId)
        }

        reserved[clientMessageId] = Date()
        return true
    }

    package func confirm(clientMessageId: String) async {
        maybeEvictAll()
        reserved.removeValue(forKey: clientMessageId)
        confirmed[clientMessageId] = Date()
    }

    package func release(clientMessageId: String) async {
        maybeEvictAll()
        reserved.removeValue(forKey: clientMessageId)
    }

    private func evictAll() {
        let now = Date()
        let confirmedCutoff = now.addingTimeInterval(-ttl)
        let reservedCutoff = now.addingTimeInterval(-reservedTTL)

        confirmed = confirmed.filter { $0.value > confirmedCutoff }
        reserved = reserved.filter { $0.value > reservedCutoff }
    }

    private func maybeEvictAll() {
        opsSinceEviction += 1
        if opsSinceEviction >= Self.evictionFrequency {
            opsSinceEviction = 0
            evictAll()
        }
    }
}
