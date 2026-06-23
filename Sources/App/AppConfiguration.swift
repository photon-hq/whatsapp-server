import Foundation
import Logging
import OTel

struct AppConfiguration: Sendable {

    let grpcHost: String
    let grpcPort: Int
    let grpcMaxRequestPayloadBytes: Int
    let grpcMaxConcurrentStreams: Int?
    let grpcMaxConnectionIdleSeconds: Int?
    let grpcKeepaliveTimeSeconds: Int
    let grpcKeepaliveTimeoutSeconds: Int
    let grpcClientMinPingIntervalSeconds: Int
    let grpcAllowKeepalivePingsWithoutCalls: Bool
    let helperSocketPath: String
    let helperTimeoutSeconds: TimeInterval
    let mediaStagingDirectory: String
    let chatStoragePath: String
    let serverDatabasePath: String
    let chatStoragePollingIntervalSeconds: TimeInterval
    let deduplicationTTLSeconds: Int
    let lightauthEndpoint: String?
    let lightauthServiceName: String
    let lightauthPublicKeyPath: String
    let spectrumCloudEndpoint: String?
    let cosmosEndpoint: String
    let cosmosApiKey: String?
    let deviceUserId: String?
    let authHTTPTimeoutSeconds: Int
    let projectVerificationCacheTTLSeconds: Int
    let authEnabled: Bool
    let otelEndpoint: String?
    let otelServiceName: String
    let otelSamplingRatio: Double
    let natsEnabled: Bool
    let natsURL: URL
    let natsSubjectPrefix: String
    let natsPublisherCursor: String
    let natsDeviceID: String?

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> AppConfiguration {
        let home = NSHomeDirectory()

        return AppConfiguration(
            grpcHost: nonEmpty(environment["GRPC_HOST"]) ?? "127.0.0.1",
            grpcPort: try parsePort(
                environment["GRPC_PORT"],
                key: "GRPC_PORT"
            ) ?? 50051,
            grpcMaxRequestPayloadBytes: try parsePositiveInt(
                environment["GRPC_MAX_REQUEST_PAYLOAD_BYTES"],
                key: "GRPC_MAX_REQUEST_PAYLOAD_BYTES",
                max: 100 * 1024 * 1024
            ) ?? 100 * 1024 * 1024,
            grpcMaxConcurrentStreams: try parsePositiveInt(
                environment["GRPC_MAX_CONCURRENT_STREAMS"],
                key: "GRPC_MAX_CONCURRENT_STREAMS",
                max: 10_000
            ) ?? 100,
            grpcMaxConnectionIdleSeconds: try parsePositiveInt(
                environment["GRPC_MAX_CONNECTION_IDLE_SECONDS"],
                key: "GRPC_MAX_CONNECTION_IDLE_SECONDS"
            ) ?? 300,
            grpcKeepaliveTimeSeconds: try parsePositiveInt(
                environment["GRPC_KEEPALIVE_TIME_SECONDS"],
                key: "GRPC_KEEPALIVE_TIME_SECONDS"
            ) ?? 60,
            grpcKeepaliveTimeoutSeconds: try parsePositiveInt(
                environment["GRPC_KEEPALIVE_TIMEOUT_SECONDS"],
                key: "GRPC_KEEPALIVE_TIMEOUT_SECONDS"
            ) ?? 20,
            grpcClientMinPingIntervalSeconds: try parsePositiveInt(
                environment["GRPC_CLIENT_MIN_PING_INTERVAL_SECONDS"],
                key: "GRPC_CLIENT_MIN_PING_INTERVAL_SECONDS"
            ) ?? 60,
            grpcAllowKeepalivePingsWithoutCalls: try parseBool(
                environment["GRPC_ALLOW_KEEPALIVE_PINGS_WITHOUT_CALLS"],
                key: "GRPC_ALLOW_KEEPALIVE_PINGS_WITHOUT_CALLS"
            ) ?? true,
            helperSocketPath: expandPath(
                nonEmpty(environment["WHATSAPP_HELPER_SOCKET_PATH"])
                    ?? home + "/Library/Containers/net.whatsapp.WhatsApp/Data/tmp/whatsapp-helper.sock"
            ),
            helperTimeoutSeconds: try parsePositiveDouble(
                environment["WHATSAPP_HELPER_TIMEOUT_SECONDS"],
                key: "WHATSAPP_HELPER_TIMEOUT_SECONDS",
                max: 300
            ) ?? 30,
            mediaStagingDirectory: expandPath(
                nonEmpty(environment["WHATSAPP_MEDIA_STAGING_DIRECTORY"])
                    ?? home + "/Library/Containers/net.whatsapp.WhatsApp/Data/tmp/whatsapp-server-media"
            ),
            chatStoragePath: expandPath(
                nonEmpty(environment["WHATSAPP_CHAT_STORAGE_PATH"])
                    ?? home + "/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite"
            ),
            serverDatabasePath: expandPath(
                nonEmpty(environment["SERVER_DATABASE_PATH"])
                    ?? home + "/Library/Application Support/whatsapp-server/server.db"
            ),
            chatStoragePollingIntervalSeconds: try parsePositiveDouble(
                environment["WHATSAPP_CHAT_STORAGE_POLLING_INTERVAL_SECONDS"],
                key: "WHATSAPP_CHAT_STORAGE_POLLING_INTERVAL_SECONDS",
                max: 60
            ) ?? 1,
            deduplicationTTLSeconds: try parsePositiveInt(
                environment["DEDUPLICATION_TTL_SECONDS"],
                key: "DEDUPLICATION_TTL_SECONDS",
                max: 86_400
            ) ?? 3_600,
            lightauthEndpoint: defaultedAllowingExplicitDisable(
                environment,
                key: "LIGHTAUTH_ENDPOINT",
                default: "http://lightauth.internal"
            ),
            lightauthServiceName: nonEmpty(environment["LIGHTAUTH_SERVICE_NAME"])
                ?? "codes.photon.whatsapp",
            lightauthPublicKeyPath: expandPath(
                nonEmpty(environment["LIGHTAUTH_PUBLIC_KEY_PATH"])
                    ?? home + "/lightauth/public.pem"
            ),
            spectrumCloudEndpoint: defaultedAllowingExplicitDisable(
                environment,
                key: "SPECTRUM_CLOUD_ENDPOINT",
                default: "https://api.photon.codes"
            ),
            cosmosEndpoint: nonEmpty(environment["COSMOS_ENDPOINT"])
                ?? "https://api.photon.codes",
            cosmosApiKey: nonEmpty(environment["COSMOS_API_KEY"]),
            deviceUserId: nonEmpty(environment["DEVICE_USER_ID"]),
            authHTTPTimeoutSeconds: try parsePositiveInt(
                environment["AUTH_HTTP_TIMEOUT_SECONDS"],
                key: "AUTH_HTTP_TIMEOUT_SECONDS"
            ) ?? 10,
            projectVerificationCacheTTLSeconds: try parsePositiveInt(
                environment["PROJECT_VERIFICATION_CACHE_TTL_SECONDS"],
                key: "PROJECT_VERIFICATION_CACHE_TTL_SECONDS"
            ) ?? 300,
            authEnabled: try parseBool(
                environment["AUTH_ENABLED"],
                key: "AUTH_ENABLED"
            ) ?? true,
            otelEndpoint: nonEmpty(environment["OTEL_EXPORTER_OTLP_ENDPOINT"]),
            otelServiceName: nonEmpty(environment["OTEL_SERVICE_NAME"]) ?? "whatsapp-server",
            otelSamplingRatio: try parseRatio(
                environment["OTEL_TRACES_SAMPLER_RATIO"],
                key: "OTEL_TRACES_SAMPLER_RATIO"
            ) ?? 1.0,
            natsEnabled: try parseBool(
                environment["NATS_ENABLED"],
                key: "NATS_ENABLED"
            ) ?? false,
            natsURL: try parseURL(
                environment["NATS_URL"],
                key: "NATS_URL"
            ) ?? URL(string: "nats://localhost:4222")!,
            natsSubjectPrefix: nonEmpty(environment["NATS_SUBJECT_PREFIX"]) ?? "whatsapp.events",
            natsPublisherCursor: nonEmpty(environment["NATS_PUBLISHER_CURSOR"]) ?? "nats_event_publisher",
            natsDeviceID: nonEmpty(environment["NATS_DEVICE_ID"])
        )
    }

    var otelConfiguration: OTel.Configuration {
        var config = OTel.Configuration.default
        config.serviceName = otelServiceName
        config.metrics.enabled = false

        if let otelEndpoint {
            config.traces.otlpExporter.endpoint = otelEndpoint
            config.traces.otlpExporter.protocol = .grpc
            config.logs.otlpExporter.endpoint = otelEndpoint
            config.logs.otlpExporter.protocol = .grpc
        } else {
            config.traces.exporter = .none
            config.logs.exporter = .none
        }

        if otelSamplingRatio < 1.0,
           let sampler = OTel.Configuration.TracesConfiguration.SamplerConfiguration
               .parentBasedTraceIDRatio(ratio: otelSamplingRatio)
        {
            config.traces.sampler = sampler
        }

        return config
    }

    var logMetadata: Logger.Metadata {
        [
            "grpc_host": "\(grpcHost)",
            "grpc_port": "\(grpcPort)",
            "grpc_max_request_payload_bytes": "\(grpcMaxRequestPayloadBytes)",
            "grpc_max_concurrent_streams": "\(grpcMaxConcurrentStreams.map(String.init) ?? "unlimited")",
            "grpc_max_connection_idle_seconds": "\(grpcMaxConnectionIdleSeconds.map(String.init) ?? "unlimited")",
            "grpc_keepalive_time_seconds": "\(grpcKeepaliveTimeSeconds)",
            "grpc_keepalive_timeout_seconds": "\(grpcKeepaliveTimeoutSeconds)",
            "grpc_client_min_ping_interval_seconds": "\(grpcClientMinPingIntervalSeconds)",
            "grpc_allow_keepalive_pings_without_calls": "\(grpcAllowKeepalivePingsWithoutCalls)",
            "helper_socket_path": "\(helperSocketPath)",
            "media_staging_directory": "\(mediaStagingDirectory)",
            "chat_storage_path": "\(chatStoragePath)",
            "server_database_path": "\(serverDatabasePath)",
            "chat_storage_polling_interval_seconds": "\(chatStoragePollingIntervalSeconds)",
            "deduplication_ttl_seconds": "\(deduplicationTTLSeconds)",
            "auth_enabled": "\(authEnabled)",
            "lightauth_endpoint": "\(lightauthEndpoint ?? "disabled")",
            "lightauth_service_name": "\(lightauthServiceName)",
            "lightauth_public_key_path": "\(lightauthPublicKeyPath)",
            "spectrum_cloud_endpoint": "\(spectrumCloudEndpoint ?? "disabled")",
            "cosmos_endpoint": "\(cosmosEndpoint)",
            "cosmos_api_key": cosmosApiKey != nil ? "<redacted>" : "none",
            "device_user_id": deviceUserId != nil ? "<redacted>" : "none",
            "auth_http_timeout_seconds": "\(authHTTPTimeoutSeconds)",
            "project_verification_cache_ttl_seconds": "\(projectVerificationCacheTTLSeconds)",
            "otel_endpoint": "\(otelEndpoint ?? "disabled")",
            "otel_service_name": "\(otelServiceName)",
            "otel_sampling_ratio": "\(otelSamplingRatio)",
            "nats_enabled": "\(natsEnabled)",
            "nats_url": "\(natsURL.absoluteString)",
            "nats_subject_prefix": "\(natsSubjectPrefix)",
            "nats_publisher_cursor": "\(natsPublisherCursor)",
            "nats_device_id": natsDeviceID != nil ? "<redacted>" : "none",
        ]
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func expandPath(_ value: String) -> String {
        (value as NSString).expandingTildeInPath
    }

    private static func defaultedAllowingExplicitDisable(
        _ environment: [String: String],
        key: String,
        default defaultValue: String
    ) -> String? {
        guard let raw = environment[key] else {
            return defaultValue
        }

        return nonEmpty(raw)
    }

    private static func parsePositiveDouble(
        _ value: String?,
        key: String,
        max: Double
    ) throws -> Double? {
        guard let value = nonEmpty(value) else { return nil }

        guard let parsed = Double(value), parsed > 0, parsed.isFinite else {
            throw AppConfigurationError.invalid(key, "must be a positive number, got \(value)")
        }

        guard parsed <= max else {
            throw AppConfigurationError.invalid(key, "must be at most \(max), got \(value)")
        }

        return parsed
    }

    private static func parsePositiveInt(
        _ value: String?,
        key: String,
        max: Int? = nil
    ) throws -> Int? {
        guard let value = nonEmpty(value) else { return nil }

        guard let parsed = Int(value), parsed > 0 else {
            throw AppConfigurationError.invalid(key, "must be a positive integer, got \(value)")
        }

        if let max, parsed > max {
            throw AppConfigurationError.invalid(key, "must be at most \(max), got \(value)")
        }

        return parsed
    }

    private static func parsePort(
        _ value: String?,
        key: String
    ) throws -> Int? {
        guard let parsed = try parsePositiveInt(value, key: key) else {
            return nil
        }

        guard parsed <= 65535 else {
            throw AppConfigurationError.invalid(key, "must be a TCP port between 1 and 65535, got \(parsed)")
        }

        return parsed
    }

    private static func parseBool(
        _ value: String?,
        key: String
    ) throws -> Bool? {
        guard let value = nonEmpty(value) else {
            return nil
        }

        switch value.lowercased() {
        case "1", "true", "yes", "y", "on":
            return true

        case "0", "false", "no", "n", "off":
            return false

        default:
            throw AppConfigurationError.invalid(key, "must be a boolean, got \(value)")
        }
    }

    private static func parseRatio(
        _ value: String?,
        key: String
    ) throws -> Double? {
        guard let value = nonEmpty(value) else {
            return nil
        }

        guard let parsed = Double(value), parsed.isFinite, (0.0...1.0).contains(parsed) else {
            throw AppConfigurationError.invalid(key, "must be a number between 0.0 and 1.0, got \(value)")
        }

        return parsed
    }

    private static func parseURL(
        _ value: String?,
        key: String
    ) throws -> URL? {
        guard let value = nonEmpty(value) else {
            return nil
        }

        guard let url = URL(string: value), url.scheme != nil, url.host != nil else {
            throw AppConfigurationError.invalid(key, "must be an absolute URL, got \(value)")
        }

        return url
    }

}


enum AppConfigurationError: Error, CustomStringConvertible {

    case invalid(String, String)

    var description: String {
        switch self {
        case .invalid(let key, let reason):
            "\(key) \(reason)"
        }
    }

}
