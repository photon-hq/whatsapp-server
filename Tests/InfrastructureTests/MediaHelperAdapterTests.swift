import Foundation
import XCTest
@testable import Domain
@testable import Infrastructure

final class MediaHelperAdapterTests: XCTestCase {

    func testMediaAdapterStagesUploadBeforeCallingHelper() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("")
        ])
        let adapter = try HelperSendMediaMessage(
            client: transport,
            stagingDirectory: directory.path
        )

        try await adapter.sendMediaMessage(
            SendMediaMessageCommand(
                recipient: "11234567890",
                type: .video,
                data: [0x01, 0x02],
                caption: "clip",
                accessibilityText: "demo clip"
            )
        )

        let actions = await transport.actions
        XCTAssertEqual(actions, ["send-media"])

        let payloads = await transport.payloads
        let data = payloads[0]
        guard case let .object(media) = data["media"] else {
            XCTFail("Expected media payload")
            return
        }

        XCTAssertEqual(data["phone"]?.stringValue, "11234567890")
        XCTAssertEqual(media["type"]?.stringValue, "video")
        let filePath = try XCTUnwrap(media["filePath"]?.stringValue)
        XCTAssertTrue(filePath.hasPrefix(directory.path))
        XCTAssertEqual(URL(fileURLWithPath: filePath).pathExtension, "mp4")
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
        XCTAssertEqual(media["caption"]?.stringValue, "clip")
        XCTAssertEqual(media["accessibilityText"]?.stringValue, "demo clip")
        XCTAssertNil(media["data"])
    }

    func testMediaAdapterCreatesMissingStagingDirectory() async throws {
        let parent = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let directory = parent.appendingPathComponent("missing-media-staging")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))

        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("")
        ])
        let adapter = try HelperSendMediaMessage(
            client: transport,
            stagingDirectory: directory.path
        )

        try await adapter.sendMediaMessage(
            SendMediaMessageCommand(
                recipient: "11234567890",
                type: .image,
                data: [0xFF, 0xD8, 0xFF]
            )
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        let payloads = await transport.payloads
        guard case let .object(media) = payloads[0]["media"] else {
            XCTFail("Expected media payload")
            return
        }

        let filePath = try XCTUnwrap(media["filePath"]?.stringValue)
        XCTAssertTrue(filePath.hasPrefix(directory.path))
        XCTAssertEqual(URL(fileURLWithPath: filePath).pathExtension, "jpg")
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
    }

    func testMediaAdapterRemovesStagedFileAfterHelperFailure() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let transport = RecordingTransport(response: [
            "accepted": .bool(false)
        ])
        let adapter = try HelperSendMediaMessage(
            client: transport,
            stagingDirectory: directory.path
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await adapter.sendMediaMessage(
                SendMediaMessageCommand(
                    recipient: "11234567890",
                    type: .image,
                    data: [0x01, 0x02]
                )
            )
        }

        let payloads = await transport.payloads
        guard case let .object(media) = payloads[0]["media"] else {
            XCTFail("Expected media payload")
            return
        }

        let filePath = try XCTUnwrap(media["filePath"]?.stringValue)
        XCTAssertFalse(FileManager.default.fileExists(atPath: filePath))
    }

}
