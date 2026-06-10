import Application
import Domain
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCOTelTracingInterceptors
import Logging

package struct GRPCTransportServer: Sendable {

    package struct Services: Sendable {

        package let messages: MessageService
        package let polls: PollService
        package let events: EventService
        package let profile: ProfileService

        package init(
            messages: MessageService,
            polls: PollService,
            events: EventService,
            profile: ProfileService
        ) {
            self.messages = messages
            self.polls = polls
            self.events = events
            self.profile = profile
        }

    }

    package struct AuthDependencies: Sendable {

        package let authVerifying: any AuthVerifying
        package let blocklistChecking: any BlocklistChecking
        package let projectVerifying: any ProjectVerifying
        package let sharedInstanceChecking: any SharedInstanceChecking

        package init(
            authVerifying: any AuthVerifying,
            blocklistChecking: any BlocklistChecking,
            projectVerifying: any ProjectVerifying,
            sharedInstanceChecking: any SharedInstanceChecking
        ) {
            self.authVerifying = authVerifying
            self.blocklistChecking = blocklistChecking
            self.projectVerifying = projectVerifying
            self.sharedInstanceChecking = sharedInstanceChecking
        }
    }

    private let config: TransportConfiguration
    private let services: Services
    private let auth: AuthDependencies?
    private let logger: Logger

    package init(
        config: TransportConfiguration,
        services: Services,
        auth: AuthDependencies?,
        logger: Logger
    ) {
        self.config = config
        self.services = services
        self.auth = auth
        self.logger = logger
    }

    static func makeInterceptors(
        config: TransportConfiguration,
        auth: AuthDependencies?,
        logger: Logger
    ) -> [any ServerInterceptor] {
        var interceptors: [any ServerInterceptor] = [
            ServerOTelTracingInterceptor(
                serverHostname: config.host,
                networkTransportMethod: "tcp"
            ),
            CallLifecycleInterceptor(logger: logger),
        ]

        if let auth {
            interceptors.append(AuthInterceptor(
                authVerifying: auth.authVerifying,
                blocklistChecking: auth.blocklistChecking,
                projectVerifying: auth.projectVerifying,
                sharedInstanceChecking: auth.sharedInstanceChecking
            ))
        }

        return interceptors
    }

    static func makeRPCServices(services: Services) -> [any RegistrableRPCService] {
        [
            MessageServiceHandler(messages: services.messages),
            PollServiceHandler(polls: services.polls),
            EventServiceHandler(events: services.events),
            ProfileServiceHandler(profile: services.profile),
        ]
    }

    package func run() async throws {
        let transportConfig = HTTP2ServerTransport.Posix.Config.defaults { c in
            c.rpc.maxRequestPayloadSize = config.maxRequestPayloadBytes

            if let maxConcurrentStreams = config.maxConcurrentStreams {
                c.http2.maxConcurrentStreams = maxConcurrentStreams
            }

            if let idleSeconds = config.maxConnectionIdleSeconds {
                c.connection.maxIdleTime = .seconds(idleSeconds)
            }

            c.connection.keepalive = .init(
                time: .seconds(config.keepaliveTimeSeconds),
                timeout: .seconds(config.keepaliveTimeoutSeconds),
                clientBehavior: .init(
                    minPingIntervalWithoutCalls: .seconds(config.clientMinPingIntervalSeconds),
                    allowWithoutCalls: config.allowKeepalivePingsWithoutCalls
                )
            )
        }

        let transport = HTTP2ServerTransport.Posix(
            address: .ipv4(host: config.host, port: config.port),
            transportSecurity: .plaintext,
            config: transportConfig
        )

        let server = GRPCServer(
            transport: transport,
            services: Self.makeRPCServices(services: services),
            interceptors: Self.makeInterceptors(config: config, auth: auth, logger: logger)
        )

        logger.info(
            "gRPC server starting",
            metadata: [
                "host": "\(config.host)",
                "port": "\(config.port)",
                "max_request_payload_bytes": "\(config.maxRequestPayloadBytes)",
                "max_concurrent_streams": "\(config.maxConcurrentStreams.map(String.init) ?? "unlimited")",
                "max_connection_idle_seconds": "\(config.maxConnectionIdleSeconds.map(String.init) ?? "unlimited")",
                "keepalive_time_seconds": "\(config.keepaliveTimeSeconds)",
                "keepalive_timeout_seconds": "\(config.keepaliveTimeoutSeconds)",
                "client_min_ping_interval_seconds": "\(config.clientMinPingIntervalSeconds)",
                "allow_keepalive_pings_without_calls": "\(config.allowKeepalivePingsWithoutCalls)",
            ]
        )

        try await server.serve()
    }

}
