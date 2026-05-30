import GRPCCore
import XCTest
@testable import Domain
@testable import Transport

final class DomainErrorRPCMappingTests: XCTestCase {

    func testClientErrorExposesMessageAndContext() {
        let error = DomainError(.invalidArgument, "recipient is required")
            .with("field", "recipient")

        let rpcError = RPCError(error)

        XCTAssertEqual(rpcError.code, .invalidArgument)
        XCTAssertEqual(rpcError.message, "recipient is required")
        XCTAssertEqual(firstString(rpcError.metadata, "error-code"), "invalidArgument")
        XCTAssertEqual(firstString(rpcError.metadata, "error-context-field"), "recipient")
    }

    func testDuplicateMessageMapsToAlreadyExists() {
        let error = DomainError(.duplicateMessage, "client_message_id was already used")

        let rpcError = RPCError(error)

        XCTAssertEqual(rpcError.code, .alreadyExists)
        XCTAssertEqual(rpcError.message, "client_message_id was already used")
        XCTAssertEqual(firstString(rpcError.metadata, "error-code"), "duplicateMessage")
    }

    func testServiceUnavailableMasksMessageAndContext() {
        let error = DomainError(.serviceUnavailable, "socket path leaked")
            .with("socket_path", "/private/tmp/helper.sock")

        let rpcError = RPCError(error)

        XCTAssertEqual(rpcError.code, .unavailable)
        XCTAssertEqual(rpcError.message, "whatsapp-helper is temporarily unavailable")
        XCTAssertEqual(firstString(rpcError.metadata, "error-code"), "serviceUnavailable")
        XCTAssertNil(firstString(rpcError.metadata, "error-context-socket_path"))
    }

    func testTimeoutExposesMessageAndContext() {
        let error = DomainError(.timeout, "Mutation did not become visible in ChatStorage in time")
            .with("message_id", "message-1")

        let rpcError = RPCError(error)

        XCTAssertEqual(rpcError.code, .deadlineExceeded)
        XCTAssertEqual(rpcError.message, "Mutation did not become visible in ChatStorage in time")
        XCTAssertEqual(firstString(rpcError.metadata, "error-code"), "timeout")
        XCTAssertEqual(firstString(rpcError.metadata, "error-context-message_id"), "message-1")
    }

    func testInternalErrorMasksMessageAndContext() {
        let error = DomainError(.internalError, "raw internal detail")
            .with("detail", "implementation detail")

        let rpcError = RPCError(error)

        XCTAssertEqual(rpcError.code, .internalError)
        XCTAssertEqual(rpcError.message, "An internal error occurred")
        XCTAssertEqual(firstString(rpcError.metadata, "error-code"), "internalError")
        XCTAssertNil(firstString(rpcError.metadata, "error-context-detail"))
    }

    func testVisibleMetadataIsPrintableAsciiAndBounded() {
        let longValue = String(repeating: "a", count: 300) + "\n中文"
        let error = DomainError(.invalidArgument, "bad input")
            .with("field", longValue)

        let rpcError = RPCError(error)
        let value = firstString(rpcError.metadata, "error-context-field")

        XCTAssertEqual(value?.count, 256)
        XCTAssertTrue(value?.hasSuffix("...[truncated]") == true)
        XCTAssertFalse(value?.contains("\n") == true)
        XCTAssertFalse(value?.contains("中文") == true)
    }

    private func firstString(
        _ metadata: Metadata,
        _ key: String
    ) -> String? {
        Array(metadata[stringValues: key]).first
    }

}
