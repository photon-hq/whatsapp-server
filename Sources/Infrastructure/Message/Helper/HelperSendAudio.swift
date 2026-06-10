import Domain
import Foundation

package struct HelperSendAudio: SendAudio, Sendable {

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

    package func sendAudio(
        _ command: SendAudioCommand
    ) async throws {
        let filePath = try stage(data: command.data, mimeType: command.mimeType)
        defer {
            try? FileManager.default.removeItem(atPath: filePath)
        }

        var media: [String: JSONValue] = [
            "filePath": .string(filePath)
        ]

        if let mimeType = command.mimeType {
            media["mimeType"] = .string(mimeType)
        }

        let data: [String: JSONValue] = [
            "phone": .string(command.recipient),
            "media": .object(media)
        ]

        let response = try await client.sendCommand(action: "send-audio", data: data)
        try HelperJSON.requireAccepted(response)
    }

    private func stage(
        data: [UInt8],
        mimeType: String?
    ) throws -> String {
        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(audioExtension(mimeType: mimeType))

        do {
            try Data(data).write(to: url, options: [.atomic])
            return url.path
        } catch {
            throw DomainError(.internalError, "Failed to stage audio upload")
                .with("path", url.path)
                .with("detail", String(describing: error))
        }
    }

    private func audioExtension(mimeType: String?) -> String {
        switch mimeType?.lowercased() {
        case "audio/aac":
            "aac"
        case "audio/mpeg", "audio/mp3":
            "mp3"
        case "audio/ogg", "audio/opus":
            "opus"
        case "audio/wav", "audio/x-wav":
            "wav"
        default:
            "m4a"
        }
    }

}
