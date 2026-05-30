import Domain
import Foundation
import Logging

package actor CosmosSharedInstanceChecker: SharedInstanceChecking {

    private let endpoint: String
    private let apiKey: String
    private let refreshInterval: TimeInterval
    private let timeout: TimeInterval
    private let session: URLSession
    private let logger: Logger

    private var cachedInstanceIds: Set<String> = []
    private var hasFetchedSuccessfully = false
    private var refreshTask: Task<Void, Never>?

    package init(
        endpoint: String,
        apiKey: String,
        refreshInterval: TimeInterval = 60,
        timeout: TimeInterval = 10,
        session: URLSession = .shared,
        logger: Logger = Logger(label: "CosmosSharedInstanceChecker")
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.refreshInterval = refreshInterval
        self.timeout = timeout
        self.session = session
        self.logger = logger
    }

    package func isAuthorized(instanceId: String) async -> Bool {
        guard hasFetchedSuccessfully else { return false }
        return cachedInstanceIds.contains(instanceId)
    }

    package func startRefreshing() async {
        await refresh()
        scheduleBackgroundRefresh()
    }

    package func stopRefreshing() async {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func refresh() async {
        do {
            let instanceIds = try await fetchInstanceIds()
            cachedInstanceIds = instanceIds
            hasFetchedSuccessfully = true
            logger.debug(
                "Shared instance list refreshed",
                metadata: ["count": "\(instanceIds.count)"]
            )
        } catch {
            if hasFetchedSuccessfully {
                logger.warning(
                    "Failed to refresh shared instance list, using stale cache",
                    metadata: [
                        "cached_count": "\(cachedInstanceIds.count)",
                        "error": "\(error)",
                    ]
                )
            } else {
                logger.error(
                    "Failed to fetch shared instance list (no cache available)",
                    metadata: ["error": "\(error)"]
                )
            }
        }
    }

    private func scheduleBackgroundRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [refreshInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshInterval))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }

    private func fetchInstanceIds() async throws -> Set<String> {
        let url = try buildURL()
        let request = buildRequest(url: url)
        let response = try await performRequest(request)
        return Set(response.keys)
    }

    private func buildURL() throws -> URL {
        let urlString = "\(endpoint)/api/v1/mac/service/shared/list"

        guard let url = URL(string: urlString) else {
            throw DomainError(.internalError, "Invalid Cosmos URL: \(urlString)")
        }

        return url
    }

    private func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> [String: SharedInstanceEntry] {
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DomainError(.serviceUnavailable, "Failed to fetch shared instance list")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DomainError(.internalError, "Unexpected response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DomainError(.serviceUnavailable, "Cosmos returned HTTP \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode([String: SharedInstanceEntry].self, from: data)
        } catch {
            throw DomainError(.internalError, "Failed to decode Cosmos response")
        }
    }
}

private struct SharedInstanceEntry: Decodable, Sendable {}
