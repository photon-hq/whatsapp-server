import Foundation
import XCTest
@testable import Domain
@testable import Infrastructure

final class SpectrumProjectVerifierTests: XCTestCase {

    override func tearDown() {
        SpectrumProjectVerifierURLProtocol.setHandler(nil)
        super.tearDown()
    }

    func testUsesWhatsAppProjectVerificationEndpoint() async throws {
        let session = URLSession(configuration: protocolBackedConfiguration())
        let verifier = SpectrumProjectVerifier(
            endpoint: "https://spectrum.example",
            session: session
        )

        SpectrumProjectVerifierURLProtocol.setHandler { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://spectrum.example/projects/project-1/whatsapp/verify"
            )
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Content-Type"),
                "application/json"
            )
            XCTAssertEqual(
                request.bodyData().flatMap { String(data: $0, encoding: .utf8) },
                #"{"instanceId":"device-1"}"#
            )

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = Data(#"{"succeed":true,"data":{"verified":true}}"#.utf8)
            return (response, body)
        }

        try await verifier.verify(projectId: "project-1", deviceUserId: "device-1")
    }

    private func protocolBackedConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SpectrumProjectVerifierURLProtocol.self]
        return configuration
    }

}

private extension URLRequest {

    func bodyData() -> Data? {
        if let httpBody {
            return httpBody
        }

        guard let httpBodyStream else {
            return nil
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)

        while httpBodyStream.hasBytesAvailable {
            let count = httpBodyStream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }

            data.append(buffer, count: count)
        }

        return data
    }

}

private final class SpectrumProjectVerifierURLProtocol: URLProtocol {

    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let handlers = HandlerStore()

    static func setHandler(_ handler: Handler?) {
        handlers.set(handler)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = Self.handlers.get()
            guard let handler else {
                throw URLError(.badServerResponse)
            }

            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

}

private final class HandlerStore: @unchecked Sendable {

    private let lock = NSLock()
    private var handler: SpectrumProjectVerifierURLProtocol.Handler?

    func set(_ handler: SpectrumProjectVerifierURLProtocol.Handler?) {
        lock.withLock {
            self.handler = handler
        }
    }

    func get() -> SpectrumProjectVerifierURLProtocol.Handler? {
        lock.withLock {
            handler
        }
    }

}
