package protocol EventObserving: Sendable {

    func startObserving() async throws

    func stopObserving() async throws

}
