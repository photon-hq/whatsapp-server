enum IdentifierInput {

    static func required(_ value: String, field: String) throws -> String {
        try TextInput.trimmedNonEmpty(value, field: field)
    }

    static func clientMessageId(_ value: String?) throws -> String? {
        guard let value else {
            return nil
        }

        return try TextInput.trimmedNonEmpty(value, field: "client_message_id")
    }
}
