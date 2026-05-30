import GRPCCore
import Logging
import XCTest
@testable import Domain
@testable import Transport

final class CallLifecycleInterceptorTests: XCTestCase {

    func testUnknownErrorBecomesInternalAndLogsFailure() async throws {
        let handler = CapturingLogHandler()
        let logger = Logger(label: "test") { _ in handler }
        let interceptor = CallLifecycleInterceptor(logger: logger)

        do {
            let _: StreamingServerResponse<PWApp_MessageResponse> = try await interceptor.intercept(
                request: request(),
                context: context()
            ) { _, _ in
                throw SampleError.boom
            }

            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .internalError)
        }

        let responseLog = handler.entries().last
        let context = responseLog?.metadata["error.context"]?.dictionary

        XCTAssertEqual(responseLog?.metadata["status"]?.firstString, "failed")
        XCTAssertEqual(responseLog?.metadata["rpc.response.status_code"]?.firstString, "INTERNAL")
        XCTAssertEqual(responseLog?.metadata["error.code"]?.firstString, "internalError")
        XCTAssertEqual(context?["detail"]?.firstString, "boom")
    }

    func testDomainErrorLogsOriginalContext() async throws {
        let handler = CapturingLogHandler()
        let logger = Logger(label: "test") { _ in handler }
        let interceptor = CallLifecycleInterceptor(logger: logger)

        do {
            let _: StreamingServerResponse<PWApp_MessageResponse> = try await interceptor.intercept(
                request: request(),
                context: context()
            ) { _, _ in
                throw DomainError(.invalidArgument, "bad input")
                    .with("field", "recipient")
            }

            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .invalidArgument)
        }

        let responseLog = handler.entries().last
        let context = responseLog?.metadata["error.context"]?.dictionary
        XCTAssertEqual(responseLog?.metadata["rpc.response.status_code"]?.firstString, "INVALID_ARGUMENT")
        XCTAssertEqual(context?["field"]?.firstString, "recipient")
    }

    func testThrownRPCErrorIsPreservedAndLogged() async throws {
        let handler = CapturingLogHandler()
        let logger = Logger(label: "test") { _ in handler }
        let interceptor = CallLifecycleInterceptor(logger: logger)

        do {
            let _: StreamingServerResponse<PWApp_MessageResponse> = try await interceptor.intercept(
                request: request(),
                context: context()
            ) { _, _ in
                throw RPCError(code: .unavailable, message: "transport unavailable")
            }

            XCTFail("Expected RPCError")
        } catch let error as RPCError {
            XCTAssertEqual(error.code, .unavailable)
            XCTAssertEqual(error.message, "transport unavailable")
        }

        let responseLog = handler.entries().last

        XCTAssertEqual(responseLog?.metadata["status"]?.firstString, "rejected")
        XCTAssertEqual(responseLog?.metadata["rpc.response.status_code"]?.firstString, "UNAVAILABLE")
        XCTAssertEqual(responseLog?.metadata["error.message"]?.firstString, "transport unavailable")
    }

    func testSuccessfulResponseLogsRequestAndResponse() async throws {
        let handler = CapturingLogHandler()
        let logger = Logger(label: "test") { _ in handler }
        let interceptor = CallLifecycleInterceptor(logger: logger)

        let response: StreamingServerResponse<PWApp_MessageResponse> = try await interceptor.intercept(
            request: request(),
            context: context()
        ) { _, _ in
            StreamingServerResponse(single: ServerResponse(message: PWApp_MessageResponse()))
        }

        if case .success(let contents) = response.accepted {
            let writer = RPCWriter<PWApp_MessageResponse>(wrapping: NoOpWriter())
            _ = try await contents.producer(writer)
        }

        let entries = handler.entries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.metadata["rpc.system.name"]?.firstString, "grpc")
        XCTAssertEqual(entries.last?.metadata["status"]?.firstString, "ok")
        XCTAssertEqual(entries.last?.metadata["rpc.response.status_code"]?.firstString, "OK")
        XCTAssertNotNil(entries.last?.metadata["duration_ms"]?.firstString)
    }

    func testRejectedRPCErrorWithDomainCauseLogsDomainError() async throws {
        let handler = CapturingLogHandler()
        let logger = Logger(label: "test") { _ in handler }
        let interceptor = CallLifecycleInterceptor(logger: logger)

        let domainError = DomainError(.invalidArgument, "bad input")
            .with("field", "recipient")

        _ = try await interceptor.intercept(
            request: request(),
            context: context()
        ) { _, _ in
            StreamingServerResponse(
                of: PWApp_MessageResponse.self,
                error: RPCError(
                    code: .invalidArgument,
                    message: "bad input",
                    cause: domainError
                )
            )
        }

        let responseLog = handler.entries().last
        let context = responseLog?.metadata["error.context"]?.dictionary

        XCTAssertEqual(responseLog?.metadata["status"]?.firstString, "failed")
        XCTAssertEqual(responseLog?.metadata["error.code"]?.firstString, "invalidArgument")
        XCTAssertEqual(context?["field"]?.firstString, "recipient")
    }

    private func request() -> StreamingServerRequest<PWApp_SendTextMessageRequest> {
        StreamingServerRequest(single: ServerRequest(
            metadata: [:],
            message: PWApp_SendTextMessageRequest()
        ))
    }

    private func context() -> ServerContext {
        ServerContext(
            descriptor: PWApp_MessageService.Method.SendTextMessage.descriptor,
            remotePeer: "in-process:test",
            localPeer: "in-process:test",
            cancellation: .init()
        )
    }

}

private enum SampleError: Error {
    case boom
}

private struct NoOpWriter<Element: Sendable>: RPCWriterProtocol {

    func write(_ element: Element) async throws {}
    func write(contentsOf elements: some Sequence<Element>) async throws {}

}

private final class CapturingLogHandler: LogHandler, @unchecked Sendable {

    struct Entry {
        let level: Logger.Level
        let message: String
        let metadata: Logger.Metadata
    }

    var metadataProvider: Logger.MetadataProvider?
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    private var storedEntries: [Entry] = []
    private let lock = NSLock()

    func log(event: LogEvent) {
        append(
            level: event.level,
            message: event.message,
            metadata: event.metadata
        )
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        append(
            level: level,
            message: message,
            metadata: metadata
        )
    }

    func entries() -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return storedEntries
    }

    private func append(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?
    ) {
        var merged = self.metadata

        if let metadata {
            for (key, value) in metadata {
                merged[key] = value
            }
        }

        let entry = Entry(
            level: level,
            message: String(describing: message),
            metadata: merged
        )

        lock.lock()
        storedEntries.append(entry)
        lock.unlock()
    }

}

private extension Logger.MetadataValue {

    var firstString: String? {
        switch self {
        case .string(let value):
            value
        case .stringConvertible(let value):
            String(describing: value)
        case .array(let values):
            values.first?.firstString
        case .dictionary:
            nil
        }
    }

    var dictionary: Logger.Metadata? {
        switch self {
        case .dictionary(let value):
            value
        default:
            nil
        }
    }

}
