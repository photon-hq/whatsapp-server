import Foundation
import GRDB
import XCTest
@testable import Domain
@testable import Infrastructure

actor RecordingTransport: HelperCommandTransport {

    private(set) var lastAction: String?
    private(set) var lastData: [String: JSONValue]?
    private(set) var actions: [String] = []
    private(set) var payloads: [[String: JSONValue]] = []
    private var responses: [[String: JSONValue]]

    init(response: [String: JSONValue]) {
        self.responses = [response]
    }

    init(responses: [[String: JSONValue]]) {
        self.responses = responses
    }

    func sendCommand(
        action: String,
        data: [String: JSONValue]
    ) async throws -> [String: JSONValue] {
        lastAction = action
        lastData = data
        actions.append(action)
        payloads.append(data)

        guard !responses.isEmpty else {
            throw DomainError(.internalError, "Missing recorded helper response")
        }

        return responses.removeFirst()
    }

}

func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("whatsapp-server-\(UUID().uuidString)")

    try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true
    )

    return url
}

func makePollKeyDatabase() throws -> String {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("ChatStorage.sqlite")
        .path
    let directory = (path as NSString).deletingLastPathComponent

    try FileManager.default.createDirectory(
        atPath: directory,
        withIntermediateDirectories: true
    )

    let pool = try DatabasePool(path: path)

    try pool.write { db in
        try db.execute(
            sql: """
                CREATE TABLE ZWACHATSESSION (
                    Z_PK INTEGER PRIMARY KEY,
                    ZCONTACTJID TEXT NOT NULL
                )
                """
        )

        try db.execute(
            sql: """
                CREATE TABLE ZWAMESSAGE (
                    Z_PK INTEGER PRIMARY KEY,
                    ZCHATSESSION INTEGER NOT NULL,
                    ZSTANZAID TEXT NOT NULL,
                    ZISFROMME BOOLEAN NOT NULL,
                    ZMESSAGETYPE INTEGER NOT NULL
                )
                """
        )

        try db.execute(
            sql: """
                INSERT INTO ZWACHATSESSION (Z_PK, ZCONTACTJID)
                VALUES (1, '48761485131844@lid')
                """
        )

        try db.execute(
            sql: """
                INSERT INTO ZWAMESSAGE
                    (Z_PK, ZCHATSESSION, ZSTANZAID, ZISFROMME, ZMESSAGETYPE)
                VALUES
                    (10, 1, '3BB730B6CA80FF723BFE', 0, 46)
                """
        )
    }

    return path
}

func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
    }
}
