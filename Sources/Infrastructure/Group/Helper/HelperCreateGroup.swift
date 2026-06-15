import Domain
import Foundation

package struct HelperCreateGroup: CreateGroup, Sendable {

    let client: any HelperCommandTransport

    package init(client: any HelperCommandTransport) {
        self.client = client
    }

    package func createGroup(
        _ command: CreateGroupCommand
    ) async throws -> GroupCreationResult {
        var data: [String: JSONValue] = [
            "subject": .string(command.subject),
            "participants": .array(command.participants.map(JSONValue.string)),
            "disappearingDuration": .number(Double(command.disappearingDuration)),
            "restrictEditInfo": .bool(command.permissions.restrictEditInfo),
            "restrictSendMessages": .bool(command.permissions.restrictSendMessages),
            "restrictAddMembers": .bool(command.permissions.restrictAddMembers),
            "restrictInviteLink": .bool(command.permissions.restrictInviteLink),
            "requireMemberApproval": .bool(command.permissions.requireMemberApproval),
        ]

        if let description = command.description {
            data["description"] = .string(description)
        }

        if let tempGuid = command.tempGuid {
            data["tempGuid"] = .string(tempGuid)
        }

        let hasAvatar = command.avatar != nil
        if let avatar = command.avatar {
            data["avatarData"] = .string(Data(avatar).base64EncodedString())
        }

        let response = try await client.sendCommand(action: "create-group", data: data)
        try HelperJSON.requireAccepted(response)

        let rawGroupJID = try HelperJSON.identifier(
            response["groupJID"] ?? response["identifier"],
            field: "groupJID",
            message: "Helper did not return a group JID"
        )

        let avatarUpdated = hasAvatar
            && (response["updated"]?.objectValue?["avatar"]?.boolValue ?? false)

        return GroupCreationResult(
            groupJID: Self.normalizeJID(rawGroupJID),
            accepted: true,
            avatarUpdated: avatarUpdated
        )
    }

    /// The helper returns the group JID via `WAJID.description`, which wraps the
    /// value in angle brackets (e.g. `<120363...@g.us>`). Strip a single matching
    /// pair so callers receive a clean `<id>@g.us` JID.
    private static func normalizeJID(_ value: String) -> String {
        guard value.count >= 2, value.hasPrefix("<"), value.hasSuffix(">") else {
            return value
        }

        return String(value.dropFirst().dropLast())
    }

}
