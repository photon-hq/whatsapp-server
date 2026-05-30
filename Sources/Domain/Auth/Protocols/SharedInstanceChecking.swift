package protocol SharedInstanceChecking: Sendable {

    func isAuthorized(instanceId: String) async -> Bool

    func startRefreshing() async

    func stopRefreshing() async
}
