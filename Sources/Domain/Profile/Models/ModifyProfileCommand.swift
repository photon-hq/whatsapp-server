package struct ModifyProfileCommand: Sendable, Equatable {

    package let name: String?
    package let about: String?
    package let avatar: [UInt8]?

    package init(
        name: String? = nil,
        about: String? = nil,
        avatar: [UInt8]? = nil
    ) {
        self.name = name
        self.about = about
        self.avatar = avatar
    }

}


package struct ProfileUpdateResult: Sendable, Equatable {

    package let nameUpdated: Bool
    package let aboutUpdated: Bool
    package let avatarUpdated: Bool

    package init(
        nameUpdated: Bool,
        aboutUpdated: Bool,
        avatarUpdated: Bool
    ) {
        self.nameUpdated = nameUpdated
        self.aboutUpdated = aboutUpdated
        self.avatarUpdated = avatarUpdated
    }

}
