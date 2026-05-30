import Domain
import Foundation

package struct SpectrumProjectVerifier: ProjectVerifying, Sendable {

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

    package func verify(projectId: String, deviceUserId: String) async throws {
        let validProjectId = try validateIdentifier(projectId, field: "project_id")
        let validDeviceUserId = try validateIdentifier(deviceUserId, field: "device_user_id")

        let url = try buildURL(projectId: validProjectId)
        let request = try buildRequest(url: url, body: AuthRequestBody(instanceId: validDeviceUserId))
        let response = try await performRequest(request)

        guard response.succeed, response.data.verified else {
            throw DomainError(.unauthorized, "Project verification failed")
                .with("project_id", projectId)
        }
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

    private func buildURL(projectId: String) throws -> URL {
        var allowedChars = CharacterSet.urlPathAllowed
        allowedChars.remove(charactersIn: "/")

        guard let encoded = projectId.addingPercentEncoding(withAllowedCharacters: allowedChars) else {
            throw DomainError(.internalError, "Failed to URL-encode projectId")
        }

        let urlString = "\(endpoint)/projects/\(encoded)/whatsapp/verify"

        guard let url = URL(string: urlString) else {
            throw DomainError(.internalError, "Invalid URL: \(urlString)")
        }

        return url
    }

    private func buildRequest(url: URL, body: AuthRequestBody) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw DomainError(.internalError, "Failed to encode request body")
        }

        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> AuthResponse {
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DomainError(.serviceUnavailable, "Failed to verify project")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DomainError(.internalError, "Unexpected response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw DomainError(.serviceUnavailable, "Spectrum Cloud returned HTTP \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(AuthResponse.self, from: data)
        } catch {
            throw DomainError(.internalError, "Failed to decode response")
        }
    }
}

private struct AuthRequestBody: Encodable, Sendable {
    let instanceId: String
}

private struct AuthResponse: Decodable, Sendable {
    let succeed: Bool
    let data: AuthResponseData
}

private struct AuthResponseData: Decodable, Sendable {
    let verified: Bool
}
