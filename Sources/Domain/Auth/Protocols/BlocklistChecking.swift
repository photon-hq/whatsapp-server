package protocol BlocklistChecking: Sendable {

    func isBlocked(jti: String) async throws -> Bool
}
