import Domain
import GRPCCore

extension DomainError: RPCErrorConvertible {

    package var rpcErrorCode: RPCError.Code {
        switch code {
        case .unauthenticated, .tokenExpired, .tokenBlocked:
            .unauthenticated
        case .unauthorized:
            .permissionDenied
        case .invalidArgument:
            .invalidArgument
        case .duplicateMessage:
            .alreadyExists
        case .serviceUnavailable:
            .unavailable
        case .messageNotFound, .pollNotFound:
            .notFound
        case .operationNotSupported:
            .failedPrecondition
        case .unimplemented:
            .unimplemented
        case .timeout:
            .deadlineExceeded
        case .internalError:
            .internalError
        }
    }

    package var rpcErrorMessage: String {
        switch code {
        case .unauthenticated, .tokenExpired, .tokenBlocked, .unauthorized:
            "Authentication failed"
        case .invalidArgument, .duplicateMessage, .messageNotFound, .pollNotFound,
             .operationNotSupported, .unimplemented:
            message
        case .serviceUnavailable:
            "whatsapp-helper is temporarily unavailable"
        case .timeout:
            message
        case .internalError:
            "An internal error occurred"
        }
    }

    package var rpcErrorMetadata: Metadata {
        var metadata = Metadata()
        metadata.addString(code.rawValue, forKey: "error-code")

        switch code {
        case .unauthenticated, .tokenExpired, .tokenBlocked, .unauthorized:
            break
        case .invalidArgument, .duplicateMessage, .messageNotFound, .pollNotFound,
             .operationNotSupported, .unimplemented:
            for (key, value) in context {
                metadata.addString(boundedPrintableASCII(value), forKey: "error-context-\(key)")
            }
        case .serviceUnavailable, .internalError:
            break
        case .timeout:
            for (key, value) in context {
                metadata.addString(boundedPrintableASCII(value), forKey: "error-context-\(key)")
            }
        }

        return metadata
    }

}
