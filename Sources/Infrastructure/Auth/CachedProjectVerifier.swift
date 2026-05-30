import Domain
import Foundation
import Logging

package actor CachedProjectVerifier: ProjectVerifying {

    private struct CacheKey: Hashable {
        let projectId: String
        let deviceUserId: String
    }

    private let inner: any ProjectVerifying
    private let ttl: TimeInterval
    private let maxSize: Int
    private var cache: [CacheKey: Date] = [:]

    private static let logger = Logger(label: "CachedProjectVerifier")

    package init(
        inner: any ProjectVerifying,
        ttlSeconds: TimeInterval = 300,
        maxSize: Int = 1024
    ) {
        self.inner = inner
        self.ttl = ttlSeconds
        self.maxSize = maxSize
    }

    package func verify(projectId: String, deviceUserId: String) async throws {
        let key = CacheKey(projectId: projectId, deviceUserId: deviceUserId)
        let now = Date()

        if let expiresAt = cache[key], expiresAt > now {
            return
        }

        try await inner.verify(projectId: projectId, deviceUserId: deviceUserId)

        if cache.count >= maxSize {
            evictExpired(now: now)
        }
        if cache.count >= maxSize, let oldestKey = cache.min(by: { $0.value < $1.value })?.key {
            cache.removeValue(forKey: oldestKey)
        }

        cache[key] = now.addingTimeInterval(ttl)
    }

    private func evictExpired(now: Date) {
        let before = cache.count
        cache = cache.filter { $0.value > now }
        let evicted = before - cache.count

        if evicted > 0 {
            Self.logger.debug("Evicted expired entries", metadata: ["count": "\(evicted)"])
        }
    }
}
