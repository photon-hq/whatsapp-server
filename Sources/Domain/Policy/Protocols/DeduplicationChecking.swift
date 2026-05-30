package protocol DeduplicationChecking: Sendable {

    func reserve(clientMessageId: String) async -> Bool

    func confirm(clientMessageId: String) async

    func release(clientMessageId: String) async
}
