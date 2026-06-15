package struct GroupPermissions: Sendable, Equatable {

    /// Only admins can edit group info.
    package let restrictEditInfo: Bool
    /// Only admins can send messages (announcement-only group).
    package let restrictSendMessages: Bool
    /// Only admins can add members.
    package let restrictAddMembers: Bool
    /// Only admins can share the invite link.
    package let restrictInviteLink: Bool
    /// New members require admin approval to join.
    package let requireMemberApproval: Bool

    package init(
        restrictEditInfo: Bool = false,
        restrictSendMessages: Bool = false,
        restrictAddMembers: Bool = false,
        restrictInviteLink: Bool = false,
        requireMemberApproval: Bool = false
    ) {
        self.restrictEditInfo = restrictEditInfo
        self.restrictSendMessages = restrictSendMessages
        self.restrictAddMembers = restrictAddMembers
        self.restrictInviteLink = restrictInviteLink
        self.requireMemberApproval = requireMemberApproval
    }

}


package struct CreateGroupCommand: Sendable, Equatable {

    package let subject: String
    package let participants: [String]
    package let description: String?
    package let avatar: [UInt8]?
    package let disappearingDuration: UInt32
    package let permissions: GroupPermissions
    package let tempGuid: String?

    package init(
        subject: String,
        participants: [String],
        description: String? = nil,
        avatar: [UInt8]? = nil,
        disappearingDuration: UInt32 = 0,
        permissions: GroupPermissions = GroupPermissions(),
        tempGuid: String? = nil
    ) {
        self.subject = subject
        self.participants = participants
        self.description = description
        self.avatar = avatar
        self.disappearingDuration = disappearingDuration
        self.permissions = permissions
        self.tempGuid = tempGuid
    }

}


package struct GroupCreationResult: Sendable, Equatable {

    package let groupJID: String
    package let accepted: Bool
    package let avatarUpdated: Bool

    package init(
        groupJID: String,
        accepted: Bool,
        avatarUpdated: Bool
    ) {
        self.groupJID = groupJID
        self.accepted = accepted
        self.avatarUpdated = avatarUpdated
    }

}
