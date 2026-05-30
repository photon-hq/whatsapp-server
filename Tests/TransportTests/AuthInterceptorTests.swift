import GRPCCore
import XCTest
@testable import Domain
@testable import Transport

final class AuthInterceptorTests: XCTestCase {

    func testRecordsAuthContextInCallState() async throws {
        let interceptor = AuthInterceptor(
            authVerifying: AuthVerifierMock(context: AuthContext(
                projectId: "project-1",
                deviceUserId: "device-1",
                tokenId: "token-1",
                expiresAt: Date().addingTimeInterval(3600)
            )),
            blocklistChecking: BlocklistCheckerMock(),
            projectVerifying: ProjectVerifierMock(),
            sharedInstanceChecking: SharedInstanceCheckerMock()
        )

        var metadata: Metadata = [:]
        metadata.addString("Bearer good-token", forKey: "authorization")

        let request = makeRequest(metadata: metadata)
        let context = makeContext()
        let callState = CallState(service: "MessageService", operation: "sendTextMessage")

        let _: StreamingServerResponse<PWApp_MessageResponse> = try await CurrentCallState.$current.withValue(callState) {
            try await interceptor.intercept(request: request, context: context) { _, _ in
                return okResponse()
            }
        }

        let fields = callState.allFields()
        XCTAssertEqual(fields["project_id"], "project-1")
        XCTAssertEqual(fields["device_user_id"], "device-1")
    }

    func testRejectsMissingAuthorizationHeader() async {
        let interceptor = AuthInterceptor(
            authVerifying: AuthVerifierMock(context: AuthContext(
                projectId: "project-1",
                deviceUserId: "device-1",
                tokenId: "token-1",
                expiresAt: Date().addingTimeInterval(3600)
            )),
            blocklistChecking: BlocklistCheckerMock(),
            projectVerifying: ProjectVerifierMock(),
            sharedInstanceChecking: SharedInstanceCheckerMock()
        )

        let flag = CallFlag()

        do {
            _ = try await interceptor.intercept(
                request: makeRequest(metadata: [:]),
                context: makeContext()
            ) { _, _ in
                await flag.mark()
                return okResponse()
            } as StreamingServerResponse<PWApp_MessageResponse>

            XCTFail("Expected auth failure")
        } catch let error as DomainError {
            let called = await flag.value()
            XCTAssertEqual(error.code, .unauthenticated)
            XCTAssertEqual(called, false)
        } catch {
            XCTFail("Expected DomainError, got \(error)")
        }
    }

    func testRejectsBlockedToken() async {
        let interceptor = AuthInterceptor(
            authVerifying: AuthVerifierMock(context: AuthContext(
                projectId: "project-1",
                deviceUserId: "device-1",
                tokenId: "token-1",
                expiresAt: Date().addingTimeInterval(3600)
            )),
            blocklistChecking: BlocklistCheckerBlockedMock(),
            projectVerifying: ProjectVerifierMock(),
            sharedInstanceChecking: SharedInstanceCheckerMock()
        )

        var metadata: Metadata = [:]
        metadata.addString("Bearer good-token", forKey: "authorization")
        let callState = CallState(service: "MessageService", operation: "sendTextMessage")

        do {
            _ = try await CurrentCallState.$current.withValue(callState) {
                try await interceptor.intercept(
                    request: makeRequest(metadata: metadata),
                    context: makeContext()
                ) { _, _ in
                    okResponse()
                }
            } as StreamingServerResponse<PWApp_MessageResponse>

            XCTFail("Expected blocked token failure")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .tokenBlocked)
        } catch {
            XCTFail("Expected DomainError, got \(error)")
        }
    }
}

private func makeContext() -> ServerContext {
    ServerContext(
        descriptor: PWApp_MessageService.Method.SendTextMessage.descriptor,
        remotePeer: "in-process:test",
        localPeer: "in-process:test",
        cancellation: .init()
    )
}

private func makeRequest(metadata: Metadata) -> StreamingServerRequest<PWApp_SendTextMessageRequest> {
    StreamingServerRequest(single: ServerRequest(
        metadata: metadata,
        message: PWApp_SendTextMessageRequest()
    ))
}

private func okResponse() -> StreamingServerResponse<PWApp_MessageResponse> {
    StreamingServerResponse(single: ServerResponse(message: PWApp_MessageResponse()))
}

private actor CallFlag {
    private var called = false

    func mark() {
        called = true
    }

    func value() -> Bool {
        called
    }
}

private actor AuthVerifierMock: AuthVerifying {
    private let context: AuthContext

    init(context: AuthContext) {
        self.context = context
    }

    func verify(token: String) async throws -> AuthContext {
        context
    }
}

private actor BlocklistCheckerMock: BlocklistChecking {
    func isBlocked(jti: String) async throws -> Bool { false }
}

private actor BlocklistCheckerBlockedMock: BlocklistChecking {
    func isBlocked(jti: String) async throws -> Bool { true }
}

private actor ProjectVerifierMock: ProjectVerifying {
    func verify(projectId: String, deviceUserId: String) async throws {}
}

private actor SharedInstanceCheckerMock: SharedInstanceChecking {
    func isAuthorized(instanceId: String) async -> Bool { true }
    func startRefreshing() async {}
    func stopRefreshing() async {}
}
