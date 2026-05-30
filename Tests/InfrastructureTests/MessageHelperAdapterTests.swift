import XCTest
@testable import Domain
@testable import Infrastructure

final class MessageHelperAdapterTests: XCTestCase {

    func testMessageAdapterMapsSendTextPayload() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("msg-1")
        ])
        let adapter = HelperSendTextMessage(client: transport)

        _ = try await adapter.sendTextMessage(
            SendTextMessageCommand(
                recipient: "11234567890",
                content: [TextBlock(text: [TextRun(text: "hello")])]
            )
        )

        let action = await transport.lastAction
        XCTAssertEqual(action, "send-message")

        let data = await transport.lastData
        XCTAssertEqual(data?["phone"]?.stringValue, "11234567890")
        XCTAssertEqual(data?["text"]?.stringValue, "hello")
        XCTAssertNil(data?["tempGuid"])
        XCTAssertNil(data?["sendOptions"])
    }

    func testMessageAdapterRejectsHelperReject() async {
        let transport = RecordingTransport(response: [
            "accepted": .bool(false)
        ])
        let adapter = HelperSendTextMessage(client: transport)

        do {
            _ = try await adapter.sendTextMessage(
                SendTextMessageCommand(
                    recipient: "11234567890",
                    content: [TextBlock(text: [TextRun(text: "hello")])]
                )
            )

            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .internalError)
            XCTAssertEqual(error.context["field"], "accepted")
        } catch {
            XCTFail("Expected DomainError")
        }
    }

    func testMessageAdapterSendsStructuredContentAsTextDocument() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("msg-1")
        ])
        let adapter = HelperSendTextMessage(client: transport)

        _ = try await adapter.sendTextMessage(
            SendTextMessageCommand(
                recipient: "11234567890",
                content: [
                    TextBlock(text: [
                        TextRun(text: "hello "),
                        TextRun(text: "world", styles: [.bold])
                    ]),
                    TextBlock(type: .bullet, text: [
                        TextRun(text: "pay "),
                        TextRun(text: "today", styles: [.italic])
                    ])
                ]
            )
        )

        let data = await transport.lastData
        XCTAssertNil(data?["text"])
        guard case let .object(textDocument) = data?["textDocument"] else {
            XCTFail("Expected textDocument payload")
            return
        }

        XCTAssertEqual(textDocument["text"]?.stringValue, "hello world\npay today")
        XCTAssertEqual(textDocument["parseMode"]?.stringValue, "structured")
        guard case let .array(spans) = textDocument["spans"] else {
            XCTFail("Expected spans array")
            return
        }
        XCTAssertEqual(spans.count, 2)
        guard case let .array(blocks) = textDocument["blocks"] else {
            XCTFail("Expected blocks array")
            return
        }
        XCTAssertEqual(blocks.count, 1)
    }

    func testMessageAdapterDoesNotStyleRunBoundaryWhitespace() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("msg-1")
        ])
        let adapter = HelperSendTextMessage(client: transport)

        _ = try await adapter.sendTextMessage(
            SendTextMessageCommand(
                recipient: "11234567890",
                content: [
                    TextBlock(text: [
                        TextRun(text: "bold", styles: [.bold]),
                        TextRun(text: " + italic ", styles: [.italic])
                    ])
                ]
            )
        )

        let data = await transport.lastData
        guard case let .object(textDocument) = data?["textDocument"],
              case let .array(spans) = textDocument["spans"] else {
            XCTFail("Expected textDocument spans")
            return
        }

        XCTAssertEqual(textDocument["text"]?.stringValue, "bold + italic ")
        XCTAssertEqual(spans.count, 2)

        guard case let .object(italic) = spans[1] else {
            XCTFail("Expected italic span")
            return
        }

        XCTAssertEqual(italic["type"]?.stringValue, "italic")
        XCTAssertEqual(italic["start"]?.intValue, 5)
        XCTAssertEqual(italic["length"]?.intValue, 8)
    }

    func testMessageAdapterKeepsWhitespaceOnlyStyledRunsUnstyled() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("msg-1")
        ])
        let adapter = HelperSendTextMessage(client: transport)

        _ = try await adapter.sendTextMessage(
            SendTextMessageCommand(
                recipient: "11234567890",
                content: [
                    TextBlock(text: [
                        TextRun(text: "hello", styles: [.bold]),
                        TextRun(text: "   ", styles: [.italic]),
                        TextRun(text: "world", styles: [.strikethrough])
                    ])
                ]
            )
        )

        let data = await transport.lastData
        guard case let .object(textDocument) = data?["textDocument"],
              case let .array(spans) = textDocument["spans"] else {
            XCTFail("Expected textDocument spans")
            return
        }

        XCTAssertEqual(textDocument["text"]?.stringValue, "hello   world")
        XCTAssertEqual(spans.count, 2)

        guard case let .object(first) = spans[0],
              case let .object(second) = spans[1] else {
            XCTFail("Expected span objects")
            return
        }

        XCTAssertEqual(first["type"]?.stringValue, "bold")
        XCTAssertEqual(first["start"]?.intValue, 0)
        XCTAssertEqual(first["length"]?.intValue, 5)
        XCTAssertEqual(second["type"]?.stringValue, "strikethrough")
        XCTAssertEqual(second["start"]?.intValue, 8)
        XCTAssertEqual(second["length"]?.intValue, 5)
    }

    func testMessageAdapterUsesUTF16OffsetsForStyledSpans() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("msg-1")
        ])
        let adapter = HelperSendTextMessage(client: transport)

        _ = try await adapter.sendTextMessage(
            SendTextMessageCommand(
                recipient: "11234567890",
                content: [
                    TextBlock(text: [
                        TextRun(text: "A🙂"),
                        TextRun(text: " bold ", styles: [.bold])
                    ])
                ]
            )
        )

        let data = await transport.lastData
        guard case let .object(textDocument) = data?["textDocument"],
              case let .array(spans) = textDocument["spans"],
              case let .object(bold) = spans.first else {
            XCTFail("Expected textDocument span")
            return
        }

        XCTAssertEqual(textDocument["text"]?.stringValue, "A🙂 bold ")
        XCTAssertEqual(bold["type"]?.stringValue, "bold")
        XCTAssertEqual(bold["start"]?.intValue, 4)
        XCTAssertEqual(bold["length"]?.intValue, 4)
    }

    func testMessageAdapterMapsLinkPreviewOnlyWhenEnabled() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("msg-1")
        ])
        let adapter = HelperSendTextMessage(client: transport)

        _ = try await adapter.sendTextMessage(
            SendTextMessageCommand(
                recipient: "11234567890",
                content: [TextBlock(text: [TextRun(text: "https://example.com")])],
                enableLinkPreview: true
            )
        )

        let data = await transport.lastData
        guard case let .object(sendOptions) = data?["sendOptions"] else {
            XCTFail("Expected sendOptions payload")
            return
        }

        XCTAssertEqual(sendOptions["linkPreview"]?.boolValue, true)
    }

    func testTextAdapterRejectsEmptyIdentifier() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("")
        ])
        let adapter = HelperSendTextMessage(client: transport)

        await XCTAssertThrowsErrorAsync {
            _ = try await adapter.sendTextMessage(
                SendTextMessageCommand(
                    recipient: "11234567890",
                    content: [TextBlock(text: [TextRun(text: "hello")])]
                )
            )
        }
    }

}
