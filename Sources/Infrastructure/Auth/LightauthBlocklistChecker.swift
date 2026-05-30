import Domain
import Foundation

package struct LightauthBlocklistChecker: BlocklistChecking, Sendable {

    private let endpoint: String
    private let timeout: TimeInterval
    private let session: URLSession

    package init(
        endpoint: String,
        timeout: TimeInterval = 10,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.timeout = timeout
        self.session = session
    }

    package func isBlocked(jti: String) async throws -> Bool {
        let validJti = try validateIdentifier(jti, field: "jti")
        let url = try buildURL(jti: validJti)
        let request = buildRequest(url: url)
        let response = try await performRequest(request)
        return response.revoked
    }

    private func validateIdentifier(_ value: String, field: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw DomainError(.invalidArgument, "\(field) must not be empty")
        }

        guard trimmed == value else {
            throw DomainError(.invalidArgument, "\(field) must not have leading/trailing whitespace")
        }

        return value
    }

    private func buildURL(jti: String) throws -> URL {
        var allowedChars = CharacterSet.urlPathAllowed
        allowedChars.remove(charactersIn: "/")

        guard let encoded = jti.addingPercentEncoding(withAllowedCharacters: allowedChars) else {
            throw DomainError(.internalError, "Failed to URL-encode jti")
        }

        let urlString = "\(endpoint)/tokens/\(encoded)/revoked"

        guard let url = URL(string: urlString) else {
            throw DomainError(.internalError, "Invalid URL: \(urlString)")
        }

        return url
    }

    private func buildRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = timeout
        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> RevokedResponse {
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DomainError(.serviceUnavailable, "Failed to check blocklist")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DomainError(.internalError, "Unexpected response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DomainError(.serviceUnavailable, "Lightauth blocklist returned HTTP \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(RevokedResponse.self, from: data)
        } catch {
            throw DomainError(.internalError, "Failed to decode response")
        }
    }
}

private struct RevokedResponse: Decodable, Sendable {
    let revoked: Bool
}
