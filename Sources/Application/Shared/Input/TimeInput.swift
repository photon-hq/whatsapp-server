import Domain
import Foundation

enum TimeInput {

    static func validateDateRange(before: Date?, after: Date?) throws {
        guard let before, let after else {
            return
        }

        guard after < before else {
            throw DomainError(.invalidArgument, "after must be earlier than before")
                .with("field", "after")
        }
    }

    static func futureDate(
        _ value: Date?,
        now: Date = Date(),
        field: String
    ) throws -> Date? {
        guard let value else {
            return nil
        }

        guard value > now else {
            throw DomainError(.invalidArgument, "\(field) must be in the future")
                .with("field", field)
        }

        return value
    }

}
