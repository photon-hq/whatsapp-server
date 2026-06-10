import Application
import Domain
import GRPCCore

struct ProfileServiceHandler: PWApp_ProfileService.ServiceProtocol {

    let profile: ProfileService

    func modifyProfile(
        request: ServerRequest<PWApp_ModifyProfileRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_ModifyProfileResponse> {
        let message = request.message

        let result = try await profile.modifyProfile(
            name: message.hasName ? message.name : nil,
            about: message.hasAbout ? message.about : nil,
            avatar: message.hasAvatar ? Array(message.avatar) : nil
        )

        var response = PWApp_ModifyProfileResponse()
        response.nameUpdated = result.nameUpdated
        response.aboutUpdated = result.aboutUpdated
        response.avatarUpdated = result.avatarUpdated

        return ServerResponse(message: response)
    }

}
