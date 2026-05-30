import Domain

package struct NoOpSharedInstanceChecker: SharedInstanceChecking, Sendable {

    package init() {}

    package func isAuthorized(instanceId: String) async -> Bool { false }
    package func startRefreshing() async {}
    package func stopRefreshing() async {}
}
