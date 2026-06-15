import Domain
import Foundation

package struct GroupService: Sendable {

    /// Disappearing-message timer values WhatsApp accepts, in seconds.
    static let allowedDisappearingDurations: Set<UInt32> = [0, 86_400, 604_800, 7_776_000]

    let createGroup: any CreateGroup

    package init(createGroup: any CreateGroup) {
        self.createGroup = createGroup
    }

    package func createGroup(
        subject: String,
        participants: [String],
        description: String?,
        avatar: [UInt8]?,
        disappearingDuration: UInt32,
        permissions: GroupPermissions,
        tempGuid: String?
    ) async throws -> GroupCreationResult {
        let trimmedSubject = try TextInput.trimmedNonEmpty(subject, field: "subject")

        guard !participants.isEmpty else {
            throw DomainError(.invalidArgument, "participants must not be empty")
                .with("field", "participants")
        }

        let normalizedParticipants = try participants.enumerated().map { index, participant in
            try Self.participant(participant, index: index)
        }

        guard Self.allowedDisappearingDurations.contains(disappearingDuration) else {
            throw DomainError(
                .invalidArgument,
                "disappearingDuration must be one of 0, 86400, 604800, 7776000"
            )
            .with("field", "disappearingDuration")
        }

        if let avatar, avatar.isEmpty {
            throw DomainError(.invalidArgument, "avatar must not be empty")
                .with("field", "avatar")
        }

        let trimmedDescription = description.map(TextInput.trim)
        let resolvedDescription = (trimmedDescription?.isEmpty ?? true) ? nil : trimmedDescription

        return try await createGroup.createGroup(
            CreateGroupCommand(
                subject: trimmedSubject,
                participants: normalizedParticipants,
                description: resolvedDescription,
                avatar: avatar,
                disappearingDuration: disappearingDuration,
                permissions: permissions,
                tempGuid: tempGuid
            )
        )
    }

    private static func participant(_ value: String, index: Int) throws -> String {
        let field = "participants[\(index)]"
        let trimmed = try TextInput.trimmedNonEmpty(value, field: field)

        guard trimmed.allSatisfy({ $0 >= "0" && $0 <= "9" }) else {
            throw DomainError(.invalidArgument, "\(field) must contain digits only")
                .with("field", field)
        }

        guard trimmed.count >= 7 else {
            throw DomainError(.invalidArgument, "\(field) must have at least 7 digits")
                .with("field", field)
        }

        guard trimmed.count <= 15 else {
            throw DomainError(.invalidArgument, "\(field) must have at most 15 digits")
                .with("field", field)
        }

        return trimmed
    }

}
