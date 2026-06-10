import Domain
import Foundation

package struct HelperSendAlbum: SendAlbum, Sendable {

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

    package func sendAlbum(
        _ command: SendAlbumCommand
    ) async throws {
        var stagedPaths: [String] = []
        defer {
            for path in stagedPaths {
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        var media: [JSONValue] = []
        for item in command.items {
            let filePath = try stage(data: item.data, type: command.type)
            stagedPaths.append(filePath)

            var entry: [String: JSONValue] = [
                "type": .string(command.type.rawValue),
                "filePath": .string(filePath)
            ]

            if let caption = item.caption {
                entry["caption"] = .string(caption)
            }

            if let accessibilityText = item.accessibilityText {
                entry["accessibilityText"] = .string(accessibilityText)
            }

            media.append(.object(entry))
        }

        let data: [String: JSONValue] = [
            "phone": .string(command.recipient),
            "media": .array(media)
        ]

        let response = try await client.sendCommand(action: "send-album", data: data)
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
            throw DomainError(.internalError, "Failed to stage album upload")
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
            if data.starts(with: [0xFF, 0xD8, 0xFF]) {
                return "jpg"
            }
            if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
                return "gif"
            }
            return "png"
        case .video:
            if data.count >= 12,
               let brand = String(bytes: data[4..<12], encoding: .ascii),
               brand.contains("ftypqt") {
                return "mov"
            }
            return "mp4"
        }
    }

}
