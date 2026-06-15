import Application
import Domain
import Foundation
import Infrastructure
import Logging
import Transport


/// Owns the dependency graph and long-lived process resources.
final class AppRuntime: Sendable {

    private let logger: Logger
    private let helperClient: HelperUDSClient
    private let eventObserver: ChatStorageEventObserver
    private let sharedInstanceChecker: any SharedInstanceChecking

    let services: GRPCTransportServer.Services
    let auth: GRPCTransportServer.AuthDependencies?

    init(config: AppConfiguration, logger: Logger) throws {
        self.logger = logger

        let helperClient = HelperUDSClient(
            socketPath: config.helperSocketPath,
            timeoutSeconds: config.helperTimeoutSeconds
        )
        self.helperClient = helperClient
        self.sharedInstanceChecker =
            if config.authEnabled, let cosmosApiKey = config.cosmosApiKey {
                CosmosSharedInstanceChecker(
                    endpoint: config.cosmosEndpoint,
                    apiKey: cosmosApiKey,
                    timeout: TimeInterval(config.authHTTPTimeoutSeconds),
                    logger: Logger(label: "CosmosSharedInstanceChecker")
                )
            } else {
                NoOpSharedInstanceChecker()
            }

        let chatStorageDatabase = try ChatStorageDatabase(path: config.chatStoragePath)
        let serverDatabase = try ServerDatabase(path: config.serverDatabasePath)

        let eventLog = DomainEventLog(database: serverDatabase)
        let eventStream = DomainEventStream(eventLog: eventLog)

        let pollStore = ChatStoragePollStore(database: chatStorageDatabase)
        let pollKeyResolver = ChatStoragePollKeyResolver(database: chatStorageDatabase)

        eventObserver = ChatStorageEventObserver(
            database: chatStorageDatabase,
            chatStoragePath: config.chatStoragePath,
            getPoll: pollStore,
            eventStreaming: eventStream,
            pollingInterval: .seconds(config.chatStoragePollingIntervalSeconds),
            logger: Logger(label: "ChatStorageEventObserver")
        )

        self.auth = try Self.makeAuthDependencies(
            config: config,
            sharedInstanceChecker: sharedInstanceChecker
        )

        let deduplicationChecker = InMemoryDeduplicationChecker(
            ttl: TimeInterval(config.deduplicationTTLSeconds)
        )

        let mutationPolicy = MutationPolicyPipeline(
            steps: [
                DeduplicateClientMessageIdStep(checker: deduplicationChecker),
            ]
        )

        let messages = MessageService(
            sendTextMessage: HelperSendTextMessage(client: helperClient),
            sendMediaMessage: try HelperSendMediaMessage(
                client: helperClient,
                stagingDirectory: config.mediaStagingDirectory
            ),
            sendAlbum: try HelperSendAlbum(
                client: helperClient,
                stagingDirectory: config.mediaStagingDirectory
            ),
            sendDocument: try HelperSendDocument(
                client: helperClient,
                stagingDirectory: config.mediaStagingDirectory
            ),
            sendAudio: try HelperSendAudio(
                client: helperClient,
                stagingDirectory: config.mediaStagingDirectory
            ),
            sendSticker: try HelperSendSticker(
                client: helperClient,
                stagingDirectory: config.mediaStagingDirectory
            ),
            sendContact: HelperSendContact(client: helperClient),
            sendReaction: HelperSendReaction(client: helperClient),
            editMessage: HelperEditMessage(client: helperClient),
            revokeMessage: HelperRevokeMessage(client: helperClient),
            deleteMessage: HelperDeleteMessage(client: helperClient),
            messageStatusQuerying: HelperMessageStatusQuerying(client: helperClient),
            messageQuerying: ChatStorageMessageQuerying(database: chatStorageDatabase),
            mutationReadback: ChatStorageMessageMutationReadback(database: chatStorageDatabase),
            mutationPolicy: mutationPolicy,
            eventStreaming: eventStream
        )

        let polls = PollService(
            createPoll: HelperCreatePoll(client: helperClient),
            votePoll: HelperVotePoll(client: helperClient, resolver: pollKeyResolver),
            unvotePoll: HelperUnvotePoll(client: helperClient, resolver: pollKeyResolver),
            getPoll: pollStore,
            mutationReadback: pollStore,
            mutationPolicy: mutationPolicy,
            eventStreaming: eventStream
        )

        services = .init(
            messages: messages,
            polls: polls,
            events: EventService(
                eventStreaming: eventStream,
                messageProjector: MessageEventProjector()
            ),
            profile: ProfileService(
                modifyProfile: try HelperModifyProfile(
                    client: helperClient,
                    stagingDirectory: config.mediaStagingDirectory
                )
            ),
            group: GroupService(
                createGroup: HelperCreateGroup(client: helperClient)
            )
        )
    }

    func start() async throws {
        await sharedInstanceChecker.startRefreshing()
        logger.info("Shared instance checker started")

        try await eventObserver.startObserving()
        logger.info("ChatStorage observer started")
    }

    func shutdown() async {
        do {
            try await eventObserver.stopObserving()
        } catch {
            logger.error(
                "Failed to stop ChatStorage observer during shutdown",
                metadata: ["error": "\(error)"]
            )
        }

        await sharedInstanceChecker.stopRefreshing()
    }

}

private extension AppRuntime {

    static func makeAuthDependencies(
        config: AppConfiguration,
        sharedInstanceChecker: any SharedInstanceChecking
    ) throws -> GRPCTransportServer.AuthDependencies? {
        guard config.authEnabled else { return nil }

        guard let lightauthEndpoint = config.lightauthEndpoint else {
            throw AuthConfigurationError.authEnabledButMissingLightauth
        }

        guard let deviceUserId = config.deviceUserId else {
            throw AuthConfigurationError.missingDeviceUserId
        }

        guard FileManager.default.fileExists(atPath: config.lightauthPublicKeyPath) else {
            throw AuthConfigurationError.missingPublicKey(path: config.lightauthPublicKeyPath)
        }

        guard let spectrumCloudEndpoint = config.spectrumCloudEndpoint else {
            throw AuthConfigurationError.authEnabledButMissingSpectrum
        }

        let authVerifier = Ed25519JWTVerifier(
            publicKeyPath: config.lightauthPublicKeyPath,
            serviceName: config.lightauthServiceName,
            deviceUserId: deviceUserId
        )

        let blocklistChecker = LightauthBlocklistChecker(
            endpoint: lightauthEndpoint,
            timeout: TimeInterval(config.authHTTPTimeoutSeconds)
        )

        let projectVerifier = CachedProjectVerifier(
            inner: SpectrumProjectVerifier(
                endpoint: spectrumCloudEndpoint,
                timeout: TimeInterval(config.authHTTPTimeoutSeconds)
            ),
            ttlSeconds: TimeInterval(config.projectVerificationCacheTTLSeconds)
        )

        return .init(
            authVerifying: authVerifier,
            blocklistChecking: blocklistChecker,
            projectVerifying: projectVerifier,
            sharedInstanceChecking: sharedInstanceChecker
        )
    }
}

private enum AuthConfigurationError: Error, LocalizedError, Sendable {
    case authEnabledButMissingLightauth
    case authEnabledButMissingSpectrum
    case missingDeviceUserId
    case missingPublicKey(path: String)

    var errorDescription: String? {
        switch self {
        case .authEnabledButMissingLightauth:
            "AUTH_ENABLED=true but LIGHTAUTH_ENDPOINT is not configured"
        case .authEnabledButMissingSpectrum:
            "AUTH_ENABLED=true but SPECTRUM_CLOUD_ENDPOINT is not configured"
        case .missingDeviceUserId:
            "AUTH_ENABLED=true but DEVICE_USER_ID is not set"
        case .missingPublicKey(let path):
            "AUTH_ENABLED=true but public key file not found at \(path)"
        }
    }
}
