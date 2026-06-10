import Domain
import Foundation

package struct HelperSendDocument: SendDocument, Sendable {

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

    package func sendDocument(
        _ command: SendDocumentCommand
    ) async throws {
        let filePath = try stage(
            data: command.data,
            fileName: command.fileName
        )
        defer {
            try? FileManager.default.removeItem(atPath: filePath)
        }

        var media: [String: JSONValue] = [
            "type": .string("document"),
            "filePath": .string(filePath)
        ]

        if let fileName = command.fileName {
            media["fileName"] = .string(fileName)
        }

        if let mimeType = command.mimeType {
            media["mimeType"] = .string(mimeType)
        }

        if let caption = command.caption {
            media["caption"] = .string(caption)
        }

        let data: [String: JSONValue] = [
            "phone": .string(command.recipient),
            "media": .object(media)
        ]

        let response = try await client.sendCommand(action: "send-document", data: data)
        try HelperJSON.requireAccepted(response)
    }

    private func stage(
        data: [UInt8],
        fileName: String?
    ) throws -> String {
        // Keep the original extension so the helper can derive a sensible
        // document type before falling back to the mimeType-based extension.
        let ext = (fileName as NSString?)?.pathExtension
        var url = directory.appendingPathComponent(UUID().uuidString)
        if let ext, !ext.isEmpty {
            url.appendPathExtension(ext)
        }

        do {
            try Data(data).write(to: url, options: [.atomic])
            return url.path
        } catch {
            throw DomainError(.internalError, "Failed to stage document upload")
                .with("path", url.path)
                .with("detail", String(describing: error))
        }
    }

}
