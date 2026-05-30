package enum ErrorCode: String, Sendable, Equatable {

    case unauthenticated
    case tokenExpired
    case tokenBlocked
    case unauthorized

    case invalidArgument
    case duplicateMessage
    case serviceUnavailable
    case messageNotFound
    case pollNotFound
    case operationNotSupported
    case unimplemented
    case timeout
    case internalError

}
