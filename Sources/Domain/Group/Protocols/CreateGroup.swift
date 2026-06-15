package protocol CreateGroup: Sendable {

    func createGroup(_ command: CreateGroupCommand) async throws -> GroupCreationResult

}
