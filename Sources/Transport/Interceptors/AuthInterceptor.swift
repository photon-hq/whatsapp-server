import Domain
import GRPCCore
import Tracing

struct AuthInterceptor: ServerInterceptor {

    private let authVerifying: any AuthVerifying
    private let blocklistChecking: any BlocklistChecking
    private let projectVerifying: any ProjectVerifying
    private let sharedInstanceChecking: any SharedInstanceChecking

    init(
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

    func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingServerRequest<Input>,
        context: ServerContext,
        next: @Sendable (
            _ request: StreamingServerRequest<Input>,
            _ context: ServerContext
        ) async throws -> StreamingServerResponse<Output>
    ) async throws -> StreamingServerResponse<Output> {
        let methodPath = context.descriptor.fullyQualifiedMethod
        let metadata = request.metadata

        guard let header = metadata.firstStringValue(forKey: "authorization"),
              header.prefix(7).lowercased() == "bearer "
        else {
            throw DomainError(.unauthenticated, "Missing or malformed authorization header")
                .with("method", methodPath)
        }

        let token = String(header.dropFirst(7))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !token.isEmpty else {
            throw DomainError(.unauthenticated, "Missing or malformed authorization header")
                .with("method", methodPath)
        }

        guard let callState = CurrentCallState.current else {
            throw DomainError(.internalError, "AuthInterceptor ran outside CallLifecycleInterceptor scope")
                .with("method", methodPath)
        }

        let authContext = try await authenticate(token: token)

        callState.setAuth(
            projectId: authContext.projectId,
            deviceUserId: authContext.deviceUserId
        )

        return try await next(request, context)
    }

    private func authenticate(token: String) async throws -> AuthContext {
        try await withSpan("auth", ofKind: .internal) { _ in
            let ctx = try await authVerifying.verify(token: token)

            async let isBlocked = blocklistChecking.isBlocked(jti: ctx.tokenId)
            async let authorized: Void = (ctx.subject == AuthConstants.sharedServiceSubject)
                ? authorizeShared(ctx: ctx)
                : authorizeDedicated(ctx: ctx)

            if try await isBlocked {
                throw DomainError(.tokenBlocked, "Token has been revoked").with("token_id", ctx.tokenId)
            }

            try await authorized
            return ctx
        }
    }

    private func authorizeShared(ctx: AuthContext) async throws {
        guard await sharedInstanceChecking.isAuthorized(instanceId: ctx.deviceUserId) else {
            throw DomainError(.unauthorized, "Device not in shared instance list")
                .with("device_user_id", ctx.deviceUserId)
        }
    }

    private func authorizeDedicated(ctx: AuthContext) async throws {
        guard let projectId = ctx.projectId else {
            throw DomainError(.unauthorized, "Dedicated token is missing a project identity")
                .with("token_id", ctx.tokenId)
        }

        do {
            try await projectVerifying.verify(projectId: projectId, deviceUserId: ctx.deviceUserId)
        } catch {
            throw DomainError(.unauthorized, "Project verification failed")
                .with("project_id", projectId)
                .with("token_id", ctx.tokenId)
        }
    }
}

private extension Metadata {

    func firstStringValue(forKey key: String) -> String? {
        for value in self[stringValues: key] {
            return value
        }
        return nil
    }
}
