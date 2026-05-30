import GRPCCore
import Logging
import XCTest
@testable import Domain
@testable import Transport

final class ServerWiringTests: XCTestCase {

    func testMakeInterceptorsPreservesOnionOrder() {
        let interceptors = GRPCTransportServer.makeInterceptors(
            config: transportConfig(),
            auth: .init(
                authVerifying: AuthVerifierNoop(),
                blocklistChecking: BlocklistCheckingNoop(),
                projectVerifying: ProjectVerifierNoop(),
                sharedInstanceChecking: SharedInstanceCheckingNoop()
            ),
            logger: Logger(label: "tests.transport.server")
        )

        XCTAssertEqual(interceptors.count, 3)

        let typeNames = interceptors.map { String(reflecting: type(of: $0)) }
        XCTAssertTrue(typeNames[0].contains("OTelTracingInterceptor"))
        XCTAssertTrue(typeNames[1].contains("CallLifecycleInterceptor"))
        XCTAssertTrue(typeNames[2].contains("AuthInterceptor"))
    }

    func testMakeInterceptorsOmitsAuthWhenDisabled() {
        let interceptors = GRPCTransportServer.makeInterceptors(
            config: transportConfig(),
            auth: nil,
            logger: Logger(label: "tests.transport.server")
        )

        XCTAssertEqual(interceptors.count, 2)

        let typeNames = interceptors.map { String(reflecting: type(of: $0)) }
        XCTAssertTrue(typeNames[0].contains("OTelTracingInterceptor"))
        XCTAssertTrue(typeNames[1].contains("CallLifecycleInterceptor"))
    }

    private func transportConfig() -> TransportConfiguration {
        TransportConfiguration(
            host: "localhost",
            port: 50051,
            maxRequestPayloadBytes: 4_194_304,
            maxConcurrentStreams: nil,
            maxConnectionIdleSeconds: nil,
            keepaliveTimeSeconds: 60,
            keepaliveTimeoutSeconds: 20,
            clientMinPingIntervalSeconds: 60,
            allowKeepalivePingsWithoutCalls: true
        )
    }
}

private actor AuthVerifierNoop: AuthVerifying {
    func verify(token: String) async throws -> AuthContext {
        AuthContext(
            projectId: "project-1",
            deviceUserId: "device-1",
            tokenId: "token-1",
            expiresAt: Date().addingTimeInterval(3600)
        )
    }
}

private actor BlocklistCheckingNoop: BlocklistChecking {
    func isBlocked(jti: String) async throws -> Bool { false }
}

private actor ProjectVerifierNoop: ProjectVerifying {
    func verify(projectId: String, deviceUserId: String) async throws {}
}

private actor SharedInstanceCheckingNoop: SharedInstanceChecking {
    func isAuthorized(instanceId: String) async -> Bool { true }
    func startRefreshing() async {}
    func stopRefreshing() async {}
}
