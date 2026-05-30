import Foundation
import XCTest
@testable import Domain
@testable import Infrastructure

final class HelperUDSClientTests: XCTestCase {

    func testSendCommandUsesLengthPrefixedHelperEnvelope() async throws {
        let socketPath = temporarySocketPath()
        let server = HelperSocketTestServer(
            socketPath: socketPath,
            response: [
                "transactionId": "ignored",
                "success": true,
                "accepted": true,
                "identifier": "msg-1",
            ]
        )

        let serverTask = Task {
            try server.runOnce()
        }

        try await waitUntilSocketExists(socketPath)

        let client = HelperUDSClient(socketPath: socketPath, timeoutSeconds: 2)
        let response = try await client.sendCommand(
            action: "send-message",
            data: ["text": .string("hello")]
        )

        XCTAssertEqual(response["accepted"]?.boolValue, true)
        XCTAssertEqual(response["identifier"]?.stringValue, "msg-1")

        let request = try await serverTask.value
        XCTAssertEqual(request.action, "send-message")
        XCTAssertEqual(request.data["text"]?.stringValue, "hello")
        XCTAssertFalse(request.transactionId.isEmpty)
    }

    func testSendCommandMapsHelperErrorEnvelope() async throws {
        let socketPath = temporarySocketPath()
        let server = HelperSocketTestServer(
            socketPath: socketPath,
            response: [
                "transactionId": "ignored",
                "success": false,
                "error": [
                    "code": "MESSAGE_NOT_FOUND",
                    "message": "not found",
                ],
            ]
        )

        let serverTask = Task {
            try server.runOnce()
        }

        try await waitUntilSocketExists(socketPath)

        let client = HelperUDSClient(socketPath: socketPath, timeoutSeconds: 2)

        do {
            _ = try await client.sendCommand(action: "send-reaction", data: [:])
            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .messageNotFound)
            XCTAssertEqual(error.message, "not found")
        }

        _ = try await serverTask.value
    }

    func testSendCommandMapsRuntimeNonmutablePollAsOperationNotSupported() async throws {
        let socketPath = temporarySocketPath()
        let server = HelperSocketTestServer(
            socketPath: socketPath,
            response: [
                "transactionId": "ignored",
                "success": false,
                "error": [
                    "code": "POLL_NOT_FOUND",
                    "message": "Target message is not a poll",
                ],
            ]
        )

        let serverTask = Task {
            try server.runOnce()
        }

        try await waitUntilSocketExists(socketPath)

        let client = HelperUDSClient(socketPath: socketPath, timeoutSeconds: 2)

        do {
            _ = try await client.sendCommand(action: "vote-poll", data: [:])
            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .operationNotSupported)
            XCTAssertEqual(error.message, "This WhatsApp runtime cannot modify this poll")
        }

        _ = try await serverTask.value
    }

    func testSendCommandRejectsMismatchedTransactionId() async throws {
        let socketPath = temporarySocketPath()
        let server = HelperSocketTestServer(
            socketPath: socketPath,
            response: [
                "transactionId": "wrong-id",
                "success": true,
                "accepted": true,
            ],
            echoTransactionId: false
        )

        let serverTask = Task {
            try server.runOnce()
        }

        try await waitUntilSocketExists(socketPath)

        let client = HelperUDSClient(socketPath: socketPath, timeoutSeconds: 2)

        do {
            _ = try await client.sendCommand(action: "send-message", data: [:])
            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .internalError)
        }

        _ = try await serverTask.value
    }

    func testSendCommandFailsWhenHelperClosesBeforeResponse() async throws {
        let socketPath = temporarySocketPath()
        let server = HelperSocketTestServer(
            socketPath: socketPath,
            response: [:],
            closeBeforeResponse: true
        )

        let serverTask = Task {
            try server.runOnce()
        }

        try await waitUntilSocketExists(socketPath)

        let client = HelperUDSClient(socketPath: socketPath, timeoutSeconds: 2)

        do {
            _ = try await client.sendCommand(action: "send-message", data: [:])
            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .serviceUnavailable)
        }

        _ = try await serverTask.value
    }

    func testSendCommandTimesOutWhenHelperKeepsConnectionOpen() async throws {
        let socketPath = temporarySocketPath()
        let server = HelperSocketTestServer(
            socketPath: socketPath,
            response: [:],
            keepOpenWithoutResponse: true
        )

        let serverTask = Task {
            try server.runOnce()
        }

        try await waitUntilSocketExists(socketPath)

        let client = HelperUDSClient(socketPath: socketPath, timeoutSeconds: 0.2)

        do {
            _ = try await client.sendCommand(action: "send-message", data: [:])
            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .timeout)
        }

        _ = try await serverTask.value
    }

    private func temporarySocketPath() -> String {
        let suffix = UUID().uuidString.prefix(8)
        return "/tmp/ws-\(suffix).sock"
    }

    private func waitUntilSocketExists(_ path: String) async throws {
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: path) {
                return
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Socket was not created")
    }

}

private final class HelperSocketTestServer: @unchecked Sendable {

    private let socketPath: String
    private let response: [String: Any]
    private let echoTransactionId: Bool
    private let closeBeforeResponse: Bool
    private let keepOpenWithoutResponse: Bool

    init(
        socketPath: String,
        response: [String: Any],
        echoTransactionId: Bool = true,
        closeBeforeResponse: Bool = false,
        keepOpenWithoutResponse: Bool = false
    ) {
        self.socketPath = socketPath
        self.response = response
        self.echoTransactionId = echoTransactionId
        self.closeBeforeResponse = closeBeforeResponse
        self.keepOpenWithoutResponse = keepOpenWithoutResponse
    }

    func runOnce() throws -> CapturedHelperRequest {
        unlink(socketPath)

        let serverFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverFD >= 0 else {
            throw POSIXError(.EIO)
        }

        defer {
            close(serverFD)
            unlink(socketPath)
        }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = Array(socketPath.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw POSIXError(.ENAMETOOLONG)
        }

        let sunPathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: sunPathCapacity) { rebound in
                for index in pathBytes.indices {
                    rebound[index] = CChar(bitPattern: pathBytes[index])
                }
                rebound[pathBytes.count] = 0
            }
        }

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(
                    serverFD,
                    socketAddress,
                    socklen_t(MemoryLayout<sockaddr_un>.size)
                )
            }
        }

        guard bindResult == 0 else {
            throw POSIXError(.EADDRINUSE)
        }

        guard listen(serverFD, 1) == 0 else {
            throw POSIXError(.EIO)
        }

        let clientFD = accept(serverFD, nil, nil)
        guard clientFD >= 0 else {
            throw POSIXError(.EIO)
        }

        defer {
            close(clientFD)
        }

        let body = try readFrame(fd: clientFD)
        let object = try JSONDecoder().decode(CapturedHelperRequest.self, from: body)

        guard !closeBeforeResponse else {
            return object
        }

        if keepOpenWithoutResponse {
            sleep(1)
            return object
        }

        var response = self.response
        if echoTransactionId {
            response["transactionId"] = object.transactionId
        }

        let responseBody = try JSONSerialization.data(withJSONObject: response)
        try writeFrame(fd: clientFD, body: responseBody)

        return object
    }

    private func readFrame(fd: Int32) throws -> Data {
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        try readExact(fd: fd, into: &lengthBytes)

        let length = lengthBytes.reduce(UInt32(0)) { partial, byte in
            (partial << 8) | UInt32(byte)
        }

        var body = [UInt8](repeating: 0, count: Int(length))
        try readExact(fd: fd, into: &body)
        return Data(body)
    }

    private func writeFrame(fd: Int32, body: Data) throws {
        let length = UInt32(body.count)
        var frame = [
            UInt8((length >> 24) & 0xFF),
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8(length & 0xFF),
        ]
        frame.append(contentsOf: body)
        try writeAll(fd: fd, bytes: frame)
    }

    private func readExact(fd: Int32, into buffer: inout [UInt8]) throws {
        var offset = 0

        while offset < buffer.count {
            let remaining = buffer.count - offset
            let readCount = buffer.withUnsafeMutableBytes { rawBuffer in
                Darwin.read(
                    fd,
                    rawBuffer.baseAddress!.advanced(by: offset),
                    remaining
                )
            }

            guard readCount > 0 else {
                throw POSIXError(.EIO)
            }

            offset += readCount
        }
    }

    private func writeAll(fd: Int32, bytes: [UInt8]) throws {
        var offset = 0

        while offset < bytes.count {
            let written = bytes.withUnsafeBytes { rawBuffer in
                Darwin.write(
                    fd,
                    rawBuffer.baseAddress!.advanced(by: offset),
                    bytes.count - offset
                )
            }

            guard written > 0 else {
                throw POSIXError(.EIO)
            }

            offset += written
        }
    }

}

private struct CapturedHelperRequest: Decodable, Sendable {

    let transactionId: String
    let action: String
    let data: [String: JSONValue]

}
