import Domain
import GRPCCore

extension Error {

    var asDomainError: DomainError {
        if let error = self as? DomainError {
            return error
        }

        if let error = self as? RPCError {
            return DomainError(.internalError, error.message)
        }

        return DomainError(.internalError, "Unhandled server error")
            .with("detail", String(describing: self))
    }
}
