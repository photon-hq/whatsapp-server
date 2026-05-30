import Domain
import Foundation

package struct HelperSendMediaMessage: SendMediaMessage, Sendable {

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

    package func sendMediaMessage(
        _ command: SendMediaMessageCommand
    ) async throws {
        let filePath = try stage(
            data: command.data,
            type: command.type
        )
        defer {
            try? FileManager.default.removeItem(atPath: filePath)
        }

        var media: [String: JSONValue] = [
            "type": .string(command.type.rawValue),
            "filePath": .string(filePath)
        ]

        if let caption = command.caption {
            media["caption"] = .string(caption)
        }

        if let accessibilityText = command.accessibilityText {
            media["accessibilityText"] = .string(accessibilityText)
        }

        let data: [String: JSONValue] = [
            "phone": .string(command.recipient),
            "media": .object(media)
        ]

        let response = try await client.sendCommand(action: "send-media", data: data)
        try HelperJSON.requireAccepted(response)
    }

    private func stage(
        data: [UInt8],
        type: MediaType
    ) throws -> String {
        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension(for: type, data: data))

        do {
            try Data(data).write(to: url, options: [.atomic])
            return url.path
        } catch {
            throw DomainError(.internalError, "Failed to stage media upload")
                .with("path", url.path)
                .with("detail", String(describing: error))
        }
    }

    private func fileExtension(
        for type: MediaType,
        data: [UInt8]
    ) -> String {
        switch type {
        case .image:
            imageExtension(data) ?? "jpg"
        case .video:
            videoExtension(data) ?? "mp4"
        }
    }

    private func imageExtension(_ data: [UInt8]) -> String? {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }

        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }

        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "gif"
        }

        return nil
    }

    private func videoExtension(_ data: [UInt8]) -> String? {
        guard data.count >= 12 else {
            return nil
        }

        let brand = String(bytes: data[4..<12], encoding: .ascii) ?? ""

        if brand.contains("ftypqt") {
            return "mov"
        }

        if brand.contains("ftyp") {
            return "mp4"
        }

        return nil
    }

}
