package protocol HelperCommandTransport: Sendable {

    func sendCommand(
        action: String,
        data: [String: JSONValue]
    ) async throws -> [String: JSONValue]

}
