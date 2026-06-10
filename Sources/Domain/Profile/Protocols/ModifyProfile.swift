package protocol ModifyProfile: Sendable {

    func modifyProfile(_ command: ModifyProfileCommand) async throws -> ProfileUpdateResult

}
