package struct TransportConfiguration: Sendable {

    package let host: String
    package let port: Int
    package let maxRequestPayloadBytes: Int
    package let maxConcurrentStreams: Int?
    package let maxConnectionIdleSeconds: Int?
    package let keepaliveTimeSeconds: Int
    package let keepaliveTimeoutSeconds: Int
    package let clientMinPingIntervalSeconds: Int
    package let allowKeepalivePingsWithoutCalls: Bool

    package init(
        host: String,
        port: Int,
        maxRequestPayloadBytes: Int,
        maxConcurrentStreams: Int?,
        maxConnectionIdleSeconds: Int?,
        keepaliveTimeSeconds: Int,
        keepaliveTimeoutSeconds: Int,
        clientMinPingIntervalSeconds: Int,
        allowKeepalivePingsWithoutCalls: Bool
    ) {
        self.host = host
        self.port = port
        self.maxRequestPayloadBytes = maxRequestPayloadBytes
        self.maxConcurrentStreams = maxConcurrentStreams
        self.maxConnectionIdleSeconds = maxConnectionIdleSeconds
        self.keepaliveTimeSeconds = keepaliveTimeSeconds
        self.keepaliveTimeoutSeconds = keepaliveTimeoutSeconds
        self.clientMinPingIntervalSeconds = clientMinPingIntervalSeconds
        self.allowKeepalivePingsWithoutCalls = allowKeepalivePingsWithoutCalls
    }

}
