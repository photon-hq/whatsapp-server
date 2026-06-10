import Domain
import Foundation

package struct HelperSendSticker: SendSticker, Sendable {

    let client: any HelperCommandTransport
    private let directory: URL

    package init(
        client: any HelperCommandTransport,
        stagingDirectory: String
    ) throws {
        self.client = client
        self.directory = URL(fileURLWithPath: stagingDirectory, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    package func sendSticker(
        _ command: SendStickerCommand
    ) async throws {
        let filePath = try stage(data: command.data)
        defer {
            try? FileManager.default.removeItem(atPath: filePath)
        }

        var media: [String: JSONValue] = [
            "filePath": .string(filePath)
        ]

        if !command.emojis.isEmpty {
            media["emojis"] = .array(command.emojis.map(JSONValue.string))
        }

        if let accessibilityText = command.accessibilityText {
            media["accessibilityText"] = .string(accessibilityText)
        }

        let data: [String: JSONValue] = [
            "phone": .string(command.recipient),
            "media": .object(media)
        ]

        let response = try await client.sendCommand(action: "send-sticker", data: data)
        try HelperJSON.requireAccepted(response)
    }

    private func stage(data: [UInt8]) throws -> String {
        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(imageExtension(data))

        do {
            try Data(data).write(to: url, options: [.atomic])
            return url.path
        } catch {
            throw DomainError(.internalError, "Failed to stage sticker upload")
                .with("path", url.path)
                .with("detail", String(describing: error))
        }
    }

    private func imageExtension(_ data: [UInt8]) -> String {
        if data.count >= 12,
           data.starts(with: [0x52, 0x49, 0x46, 0x46]),
           Array(data[8..<12]) == [0x57, 0x45, 0x42, 0x50] {
            return "webp"
        }

        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }

        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }

        return "png"
    }

}
