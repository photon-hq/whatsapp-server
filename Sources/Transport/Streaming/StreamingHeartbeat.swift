import GRPCCore

enum StreamingHeartbeat {

    static let interval: Duration = .seconds(30)

    static func response<Events: AsyncSequence & Sendable, Response: Sendable>(
        from stream: Events,
        mapEvent: @escaping @Sendable (Events.Element) throws -> Response,
        makeHeartbeat: @escaping @Sendable () -> Response
    ) -> StreamingServerResponse<Response> {
        makeResponse(
            from: stream,
            mapEvent: mapEvent,
            makeHeartbeat: makeHeartbeat
        )
    }

    static func finiteResponse<Events: AsyncSequence & Sendable, Response: Sendable>(
        from stream: Events,
        mapEvent: @escaping @Sendable (Events.Element) throws -> Response,
        makeHeartbeat: @escaping @Sendable () -> Response,
        makeComplete: @escaping @Sendable () -> Response
    ) -> StreamingServerResponse<Response> {
        makeResponse(
            from: stream,
            mapEvent: mapEvent,
            makeHeartbeat: makeHeartbeat,
            makeComplete: makeComplete
        )
    }

    private static func makeResponse<Events: AsyncSequence & Sendable, Response: Sendable>(
        from stream: Events,
        mapEvent: @escaping @Sendable (Events.Element) throws -> Response,
        makeHeartbeat: @escaping @Sendable () -> Response,
        makeComplete: (@Sendable () -> Response)? = nil
    ) -> StreamingServerResponse<Response> {
        StreamingServerResponse(metadata: [:]) { writer in
            do {
                try await writer.write(makeHeartbeat())

                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for try await event in stream {
                            try await writer.write(try mapEvent(event))
                        }
                    }

                    group.addTask {
                        do {
                            while !Task.isCancelled {
                                try await Task.sleep(for: interval)
                                try await writer.write(makeHeartbeat())
                            }
                        } catch is CancellationError {
                        }
                    }

                    _ = try await group.next()
                    group.cancelAll()
                    try await group.waitForAll()
                }

                if let makeComplete {
                    try await writer.write(makeComplete())
                }

                return [:]
            } catch {
                throw StreamDisconnectNormalizer.normalize(error)
            }
        }
    }

}
