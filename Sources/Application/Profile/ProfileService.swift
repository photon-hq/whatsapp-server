import Domain
import Foundation

package struct ProfileService: Sendable {

    let modifyProfile: any ModifyProfile

    package init(modifyProfile: any ModifyProfile) {
        self.modifyProfile = modifyProfile
    }

    package func modifyProfile(
        name: String?,
        about: String?,
        avatar: [UInt8]?
    ) async throws -> ProfileUpdateResult {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedName, trimmedName.isEmpty {
            throw DomainError(.invalidArgument, "name must not be empty")
                .with("field", "name")
        }

        if let avatar, avatar.isEmpty {
            throw DomainError(.invalidArgument, "avatar must not be empty")
                .with("field", "avatar")
        }

        guard trimmedName != nil || about != nil || avatar != nil else {
            throw DomainError(.invalidArgument, "at least one of name, about, or avatar is required")
                .with("field", "name")
        }

        return try await modifyProfile.modifyProfile(
            ModifyProfileCommand(
                name: trimmedName,
                about: about,
                avatar: avatar
            )
        )
    }

}
