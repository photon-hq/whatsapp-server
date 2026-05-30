package struct DomainError: Error, Sendable, Equatable {

    package let code: ErrorCode
    package let message: String
    package let context: [String: String]

    package init(
        _ code: ErrorCode,
        _ message: String,
        context: [String: String] = [:]
    ) {
        self.code = code
        self.message = message
        self.context = context
    }

    package func with(_ key: String, _ value: String) -> DomainError {
        var context = self.context
        context[key] = value
        return DomainError(code, message, context: context)
    }

    package func with(_ key: String, _ value: Int) -> DomainError {
        with(key, String(value))
    }

}
