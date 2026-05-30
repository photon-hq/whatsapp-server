import Domain
import Foundation
import GRPCCore
import Logging

struct RPCLogContext {

    let logger: Logger
    let fullMethod: String
    let startTime: ContinuousClock.Instant
    let requestMetadata: Logger.Metadata

    func logRequest() {
        logger.log(level: .info, "[REQ] \(fullMethod)", metadata: requestMetadata)
    }

    func logOK(callState: CallState) {
        var meta = responseMetadata(callState: callState)
        meta["status"] = "ok"
        meta["rpc.response.status_code"] = "OK"

        logger.log(level: .info, "[RES] \(fullMethod) OK", metadata: meta)
    }

    func logCancelled(callState: CallState) {
        var meta = responseMetadata(callState: callState)
        meta["status"] = "cancelled"
        meta["rpc.response.status_code"] = "CANCELLED"

        logger.log(level: .info, "[RES] \(fullMethod) cancelled", metadata: meta)
    }

    func logFailed(_ error: DomainError, callState: CallState) {
        var meta = responseMetadata(callState: callState)

        let code = error.rpcErrorCode
        let status = statusName(code)

        meta["status"] = "failed"
        meta["rpc.response.status_code"] = "\(status)"
        meta["error.type"] = "\(status)"
        meta["error.code"] = "\(error.code.rawValue)"
        meta["error.message"] = "\(boundedPrintableASCII(error.message))"

        if !error.context.isEmpty {
            meta["error.context"] = .dictionary(
                error.context.mapValues { .string(boundedPrintableASCII($0)) }
            )
        }

        logger.log(level: logLevel(for: code), "[RES] \(fullMethod) failed", metadata: meta)
    }

    func logResponseFailure(_ error: RPCError, callState: CallState) {
        if let domainError = error.cause as? DomainError {
            logFailed(domainError, callState: callState)
            return
        }

        var meta = responseMetadata(callState: callState)

        let status = statusName(error.code)
        meta["status"] = "rejected"
        meta["rpc.response.status_code"] = "\(status)"
        meta["error.type"] = "\(status)"
        meta["error.message"] = "\(boundedPrintableASCII(error.message))"

        logger.log(level: logLevel(for: error.code), "[RES] \(fullMethod) rejected", metadata: meta)
    }

    private func responseMetadata(callState: CallState) -> Logger.Metadata {
        var meta = requestMetadata
        let duration = (ContinuousClock.now - startTime).components
        meta["duration_ms"] = "\(duration.seconds * 1_000 + duration.attoseconds / 1_000_000_000_000_000)"

        let fields = callState.allFields()
        if let value = fields["project_id"] {
            meta["project_id"] = "\(boundedPrintableASCII(value))"
        }
        if let value = fields["device_user_id"] {
            meta["device_user_id"] = "\(boundedPrintableASCII(value))"
        }
        if let value = fields["app_service"] {
            meta["app_service"] = "\(boundedPrintableASCII(value))"
        }
        if let value = fields["app_operation"] {
            meta["app_operation"] = "\(boundedPrintableASCII(value))"
        }

        return meta
    }

}

private func statusName(_ code: RPCError.Code) -> String {
    statusNames[code] ?? "UNKNOWN"
}

private func logLevel(for code: RPCError.Code) -> Logger.Level {
    callerErrorCodes.contains(code) ? .info : .error
}

private let statusNames: [RPCError.Code: String] = [
    .cancelled: "CANCELLED",
    .unknown: "UNKNOWN",
    .invalidArgument: "INVALID_ARGUMENT",
    .deadlineExceeded: "DEADLINE_EXCEEDED",
    .notFound: "NOT_FOUND",
    .alreadyExists: "ALREADY_EXISTS",
    .permissionDenied: "PERMISSION_DENIED",
    .resourceExhausted: "RESOURCE_EXHAUSTED",
    .failedPrecondition: "FAILED_PRECONDITION",
    .aborted: "ABORTED",
    .outOfRange: "OUT_OF_RANGE",
    .unimplemented: "UNIMPLEMENTED",
    .internalError: "INTERNAL",
    .unavailable: "UNAVAILABLE",
    .dataLoss: "DATA_LOSS",
    .unauthenticated: "UNAUTHENTICATED",
]

private let callerErrorCodes: Set<RPCError.Code> = [
    .invalidArgument,
    .failedPrecondition,
    .outOfRange,
    .unauthenticated,
    .permissionDenied,
    .notFound,
    .alreadyExists,
    .aborted,
    .cancelled,
    .resourceExhausted,
]
