import Darwin
import Logging
import OTel
import ServiceLifecycle
import Tracing
import Transport


extension GRPCTransportServer: Service {}


let serviceLabel = "codes.photon.whatsapp-server"


let config: AppConfiguration
do {
    config = try AppConfiguration.fromEnvironment()
} catch {
    Logger(label: serviceLabel).critical("Invalid configuration", metadata: ["error": "\(error)"])
    exit(1)
}


let otelConfig = config.otelConfiguration
let tracing = try OTel.makeTracingBackend(configuration: otelConfig)
let logging = try OTel.makeLoggingBackend(configuration: otelConfig)

InstrumentationSystem.bootstrap(tracing.factory)

LoggingSystem.bootstrap { label in
    MultiplexLogHandler([
        logging.factory(label),
        StreamLogHandler.standardError(label: label),
    ])
}

let logger = Logger(label: serviceLabel)


let runtime: AppRuntime
do {
    runtime = try AppRuntime(config: config, logger: logger)
} catch {
    logger.critical("AppRuntime init failed", metadata: ["error": "\(error)"])
    exit(1)
}

do {
    try await runtime.start()
} catch {
    logger.critical("Failed to start services", metadata: ["error": "\(error)"])
    await runtime.shutdown()
    exit(1)
}

let server = GRPCTransportServer(
    config: .init(
        host: config.grpcHost,
        port: config.grpcPort,
        maxRequestPayloadBytes: config.grpcMaxRequestPayloadBytes,
        maxConcurrentStreams: config.grpcMaxConcurrentStreams,
        maxConnectionIdleSeconds: config.grpcMaxConnectionIdleSeconds,
        keepaliveTimeSeconds: config.grpcKeepaliveTimeSeconds,
        keepaliveTimeoutSeconds: config.grpcKeepaliveTimeoutSeconds,
        clientMinPingIntervalSeconds: config.grpcClientMinPingIntervalSeconds,
        allowKeepalivePingsWithoutCalls: config.grpcAllowKeepalivePingsWithoutCalls
    ),
    services: runtime.services,
    auth: runtime.auth,
    logger: Logger(label: "transport.grpc")
)

logger.info("Starting", metadata: config.logMetadata)


var serviceGroupFailed = false

do {
    try await ServiceGroup(
        services: [tracing.service, logging.service, server],
        gracefulShutdownSignals: [.sigint, .sigterm],
        logger: logger
    ).run()
} catch {
    logger.critical("ServiceGroup terminated with error", metadata: ["error": "\(error)"])
    serviceGroupFailed = true
}

await runtime.shutdown()
logger.info("Stopped")

if serviceGroupFailed {
    exit(1)
}
