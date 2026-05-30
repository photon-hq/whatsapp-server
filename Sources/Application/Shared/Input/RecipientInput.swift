import Domain

enum RecipientInput {

    static func phone(_ value: String) throws -> String {
        let field = "recipient"
        let trimmed = try TextInput.trimmedNonEmpty(value, field: field)

        guard trimmed.allSatisfy({ $0 >= "0" && $0 <= "9" }) else {
            throw DomainError(.invalidArgument, "\(field) must contain digits only")
                .with("field", field)
        }

        guard trimmed.count >= 7 else {
            throw DomainError(.invalidArgument, "\(field) must have at least 7 digits")
                .with("field", field)
        }

        guard trimmed.count <= 15 else {
            throw DomainError(.invalidArgument, "\(field) must have at most 15 digits")
                .with("field", field)
        }

        return trimmed
    }
}
