import Domain

enum NumberInput {

    static func pageSize(
        _ value: Int?,
        default defaultValue: Int = 50,
        max: Int = 100,
        field: String = "page_size"
    ) throws -> Int {
        guard let value else {
            return defaultValue
        }

        guard (1...max).contains(value) else {
            throw DomainError(.invalidArgument, "\(field) must be between 1 and \(max)")
                .with("field", field)
                .with("value", value)
        }

        return value
    }

    static func nonNegativeIndexes(
        _ values: [Int],
        field: String
    ) throws -> [Int] {
        guard !values.isEmpty else {
            throw DomainError(.invalidArgument, "\(field) must contain at least one index")
                .with("field", field)
        }

        for value in values where value < 0 {
            throw DomainError(.invalidArgument, "\(field) must contain non-negative indexes")
                .with("field", field)
                .with("value", value)
        }

        guard Set(values).count == values.count else {
            throw DomainError(.invalidArgument, "\(field) must not contain duplicate indexes")
                .with("field", field)
        }

        return values
    }
}
