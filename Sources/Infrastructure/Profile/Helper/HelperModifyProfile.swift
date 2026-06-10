import Domain
import Foundation

package struct HelperModifyProfile: ModifyProfile, Sendable {

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

    package func modifyProfile(
        _ command: ModifyProfileCommand
    ) async throws -> ProfileUpdateResult {
        var data: [String: JSONValue] = [:]

        if let name = command.name {
            data["name"] = .string(name)
        }

        if let about = command.about {
            data["about"] = .string(about)
        }

        var stagedAvatarPath: String?
        if let avatar = command.avatar {
            let path = try stage(avatar: avatar)
            stagedAvatarPath = path
            data["avatarPath"] = .string(path)
        }
        defer {
            if let stagedAvatarPath {
                try? FileManager.default.removeItem(atPath: stagedAvatarPath)
            }
        }

        let response = try await client.sendCommand(action: "modify-profile", data: data)
        try HelperJSON.requireAccepted(response)

        let updated = response["updated"]?.objectValue ?? [:]

        return ProfileUpdateResult(
            nameUpdated: updated["name"]?.boolValue ?? false,
            aboutUpdated: updated["about"]?.boolValue ?? false,
            avatarUpdated: updated["avatar"]?.boolValue ?? false
        )
    }

    private func stage(avatar: [UInt8]) throws -> String {
        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(imageExtension(avatar))

        do {
            try Data(avatar).write(to: url, options: [.atomic])
            return url.path
        } catch {
            throw DomainError(.internalError, "Failed to stage avatar upload")
                .with("path", url.path)
                .with("detail", String(describing: error))
        }
    }

    private func imageExtension(_ data: [UInt8]) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }

        return "jpg"
    }

}
