package protocol AuthVerifying: Sendable {

    func verify(token: String) async throws -> AuthContext
}
