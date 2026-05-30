import Domain
import Foundation
import NIOCore
import NIOPosix

package actor HelperUDSClient: HelperCommandTransport {

    private let group: MultiThreadedEventLoopGroup
    private let socketPath: String
    private let timeoutSeconds: TimeInterval
    private let maxFrameBytes: Int

    package init(
        socketPath: String,
        timeoutSeconds: TimeInterval = 30,
        maxFrameBytes: Int = 4 * 1024 * 1024
    ) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.socketPath = socketPath
        self.timeoutSeconds = timeoutSeconds
        self.maxFrameBytes = maxFrameBytes
    }

    deinit {
        try? group.syncShutdownGracefully()
    }

    package func sendCommand(
        action: String,
        data: [String: JSONValue]
    ) async throws -> [String: JSONValue] {
        let transactionId = "\(action)-\(UUID().uuidString)"
        let request = HelperRequest(
            transactionId: transactionId,
            action: action,
            data: data
        )

        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(request)
        } catch {
            throw DomainError(.internalError, "Failed to encode helper request")
                .with("action", action)
        }

        guard requestBody.count <= maxFrameBytes else {
            throw DomainError(.invalidArgument, "Helper request exceeds frame limit")
                .with("action", action)
                .with("max_frame_bytes", maxFrameBytes)
        }

        do {
            let responseBody = try await sendFrame(requestBody)
            let response = try JSONDecoder().decode(HelperResponse.self, from: responseBody)

            guard response.transactionId == transactionId else {
                throw DomainError(.internalError, "Helper response transaction id does not match request")
                    .with("action", action)
            }

            if response.success {
                return response.payload
            }

            let error = response.error
            throw helperError(
                code: error?.code ?? "INTERNAL_ERROR",
                message: error?.message ?? "Helper returned an error"
            )
        } catch let error as DomainError {
            throw error
        } catch let error as NIOConnectionError {
            throw DomainError(.serviceUnavailable, "Unable to connect to whatsapp-helper")
                .with("socket_path", socketPath)
                .with("detail", String(describing: error))
        } catch {
            throw DomainError(.internalError, "Helper request failed")
                .with("socket_path", socketPath)
                .with("action", action)
                .with("detail", String(describing: error))
        }
    }

    private func sendFrame(_ body: Data) async throws -> Data {
        let maxFrameBytes = self.maxFrameBytes
        let bootstrap = ClientBootstrap(group: group)
            .connectTimeout(.milliseconds(Int64(timeoutSeconds * 1000)))
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    try channel.pipeline.syncOperations.addHandler(
                        HelperChannelHandler(
                            requestBody: body,
                            maxFrameBytes: maxFrameBytes,
                            eventLoop: channel.eventLoop
                        )
                    )
                }
            }

        let channel = try await bootstrap.connect(unixDomainSocketPath: socketPath).get()

        let handler = try await channel.pipeline.handler(type: HelperChannelHandler.self).get()

        do {
            let result = try await withTimeout(
                channel: channel,
                response: handler.response
            )

            try? await channel.close().get()
            return result
        } catch {
            try? await channel.close().get()
            throw error
        }
    }

    private func withTimeout(
        channel: Channel,
        response: EventLoopFuture<Data>
    ) async throws -> Data {
        let promise = channel.eventLoop.makePromise(of: Data.self)

        response.whenComplete { result in
            promise.completeWith(result)
        }

        let timeout = channel.eventLoop.scheduleTask(
            in: .milliseconds(Int64(timeoutSeconds * 1000))
        ) {
            promise.fail(DomainError(.timeout, "Timed out waiting for whatsapp-helper"))
            channel.close(promise: nil)
        }

        promise.futureResult.whenComplete { _ in
            timeout.cancel()
        }

        return try await promise.futureResult.get()
    }

}


private func helperError(code: String, message: String) -> DomainError {
    switch code {
    case "INVALID_REQUEST", "INVALID_ARGUMENT":
        return DomainError(.invalidArgument, message)

    case "WHATSAPP_CONTEXT_UNAVAILABLE":
        return DomainError(.serviceUnavailable, message)

    case "MESSAGE_NOT_FOUND":
        return DomainError(.messageNotFound, message)

    case "POLL_NOT_FOUND":
        if message == "Target message is not a poll" {
            return DomainError(
                .operationNotSupported,
                "This WhatsApp runtime cannot modify this poll"
            )
        }

        return DomainError(.pollNotFound, message)

    case "UNSUPPORTED":
        return DomainError(.operationNotSupported, message)

    case "UNIMPLEMENTED":
        return DomainError(.unimplemented, message)

    default:
        return DomainError(.internalError, message)
    }
}
