package enum ReadbackRetry {

    package static let standardDelaysNs: [UInt64] = [
        0,
        50_000_000,
        100_000_000,
        250_000_000,
        500_000_000,
        1_000_000_000,
        2_000_000_000,
        3_000_000_000,
        5_000_000_000,
        8_000_000_000,
    ]

    static func search<T: Sendable>(
        delaysNs: [UInt64] = standardDelaysNs,
        attempt: @escaping @Sendable () async throws -> T?,
        matches: @escaping @Sendable (T) -> Bool = { _ in true }
    ) async throws -> T? {
        for delay in delaysNs {
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }

            guard let value = try await attempt() else {
                continue
            }

            if matches(value) {
                return value
            }
        }

        return nil
    }

}
