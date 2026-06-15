import Domain

enum RecipientInput {

    /// JID suffixes that address an existing WhatsApp chat session.
    static let jidSuffixes = ["@lid", "@s.whatsapp.net", "@g.us"]

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

    /// Accepts either a digits-only phone number or a WhatsApp JID
    /// (`@lid`, `@s.whatsapp.net`, `@g.us`). Read/query paths use this because
    /// callers may pass the `chatJid` returned on a message snapshot, which is
    /// frequently an opaque `@lid` session that cannot be expressed as a phone
    /// number. Send paths keep using ``phone(_:)`` so outgoing addressing stays
    /// strictly numeric.
    static func phoneOrJid(_ value: String) throws -> String {
        let field = "recipient"
        let trimmed = try TextInput.trimmedNonEmpty(value, field: field)

        if isJid(trimmed) {
            return trimmed
        }

        return try phone(value)
    }

    static func isJid(_ value: String) -> Bool {
        jidSuffixes.contains { value.hasSuffix($0) && value.count > $0.count }
    }
}
