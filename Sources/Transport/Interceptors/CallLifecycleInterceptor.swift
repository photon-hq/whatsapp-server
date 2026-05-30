import Domain
import Foundation
import GRPCCore
import Logging

struct CallLifecycleInterceptor: ServerInterceptor {

    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingServerRequest<Input>,
        context: ServerContext,
        next: @Sendable (
            _ request: StreamingServerRequest<Input>,
            _ context: ServerContext
        ) async throws -> StreamingServerResponse<Output>
    ) async throws -> StreamingServerResponse<Output> {
        let fullMethod = context.descriptor.fullyQualifiedMethod

        let logContext = RPCLogContext(
            logger: logger,
            fullMethod: fullMethod,
            startTime: ContinuousClock.now,
            requestMetadata: [
                "request_id": "\(UUID().uuidString)",
                "rpc.system.name": "grpc",
                "rpc.method": "\(fullMethod)",
                "network.peer.address": "\(context.remotePeer)",
            ]
        )

        let operation = context.descriptor.method.prefix(1).lowercased()
                      + context.descriptor.method.dropFirst()

        let callState = CallState(
            service: context.descriptor.service.service,
            operation: operation
        )

        logContext.logRequest()

        return try await CurrentCallState.$current.withValue(callState) {
            do {
                var response = try await next(request, context)

                switch response.accepted {
                case .success(var contents):
                    contents.producer = Self.makeLoggedProducer(
                        originalProducer: contents.producer,
                        rpcLogContext: logContext,
                        callState: callState
                    )
                    response.accepted = .success(contents)

                case .failure(let rpcError):
                    logContext.logResponseFailure(rpcError, callState: callState)
                }

                return response
            } catch {
                throw Self.normalizeAndLog(error, rpcLogContext: logContext, callState: callState)
            }
        }
    }

    private static func makeLoggedProducer<Output: Sendable>(
        originalProducer: @escaping @Sendable (RPCWriter<Output>) async throws -> Metadata,
        rpcLogContext: RPCLogContext,
        callState: CallState
    ) -> @Sendable (RPCWriter<Output>) async throws -> Metadata {
        { writer in
            do {
                let trailer = try await CurrentCallState.$current.withValue(callState) {
                    try await originalProducer(writer)
                }
                rpcLogContext.logOK(callState: callState)
                return trailer
            } catch {
                throw normalizeAndLog(error, rpcLogContext: rpcLogContext, callState: callState)
            }
        }
    }

    private static func normalizeAndLog(
        _ error: any Error,
        rpcLogContext: RPCLogContext,
        callState: CallState
    ) -> any Error {
        if error is CancellationError {
            rpcLogContext.logCancelled(callState: callState)
            return error
        }

        if let rpcError = error as? RPCError {
            rpcLogContext.logResponseFailure(rpcError, callState: callState)
            return rpcError
        }

        let domainError = error.asDomainError
        rpcLogContext.logFailed(domainError, callState: callState)
        return domainError
    }
}
