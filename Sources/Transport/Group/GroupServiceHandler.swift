import Application
import Domain
import GRPCCore

struct GroupServiceHandler: PWApp_GroupService.ServiceProtocol {

    let group: GroupService

    func createGroup(
        request: ServerRequest<PWApp_CreateGroupRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_CreateGroupResponse> {
        let message = request.message

        let permissions = GroupPermissions(
            restrictEditInfo: message.restrictEditInfo,
            restrictSendMessages: message.restrictSendMessages,
            restrictAddMembers: message.restrictAddMembers,
            restrictInviteLink: message.restrictInviteLink,
            requireMemberApproval: message.requireMemberApproval
        )

        let result = try await group.createGroup(
            subject: message.subject,
            participants: message.participants,
            description: message.hasGroupDescription ? message.groupDescription : nil,
            avatar: message.hasAvatar ? Array(message.avatar) : nil,
            disappearingDuration: message.hasDisappearingDuration ? message.disappearingDuration : 0,
            permissions: permissions,
            tempGuid: message.hasTempGuid ? message.tempGuid : nil
        )

        var response = PWApp_CreateGroupResponse()
        response.groupJid = result.groupJID
        response.accepted = result.accepted
        response.avatarUpdated = result.avatarUpdated

        return ServerResponse(message: response)
    }

}
