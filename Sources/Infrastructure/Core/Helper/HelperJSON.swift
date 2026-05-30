import Domain

enum HelperJSON {

    static func requireAccepted(
        _ response: [String: JSONValue]
    ) throws {
        guard try bool(response["accepted"], field: "accepted") else {
            throw DomainError(.internalError, "Helper rejected the command")
                .with("field", "accepted")
        }
    }

    static func identifier(
        _ value: JSONValue?,
        field: String,
        message: String
    ) throws -> String {
        guard let identifier = value?.stringValue, !identifier.isEmpty else {
            throw DomainError(.internalError, message)
                .with("field", field)
        }

        return identifier
    }

    static func bool(
        _ value: JSONValue?,
        field: String
    ) throws -> Bool {
        guard let bool = value?.boolValue else {
            throw invalidField(field)
        }

        return bool
    }

    static func int(
        _ value: JSONValue?,
        field: String
    ) throws -> Int {
        guard let int = value?.intValue else {
            throw invalidField(field)
        }

        return int
    }

    static func string(
        _ value: JSONValue?,
        field: String,
        allowEmpty: Bool = false
    ) throws -> String {
        guard let string = value?.stringValue else {
            throw invalidField(field)
        }

        guard allowEmpty || !string.isEmpty else {
            throw invalidField(field)
        }

        return string
    }

    static func object(
        _ value: JSONValue?,
        field: String
    ) throws -> [String: JSONValue] {
        guard let object = value?.objectValue else {
            throw invalidField(field)
        }

        return object
    }

    static func array(
        _ value: JSONValue?,
        field: String
    ) throws -> [JSONValue] {
        guard let array = value?.arrayValue else {
            throw invalidField(field)
        }

        return array
    }

    static func invalidField(_ field: String) -> DomainError {
        DomainError(.internalError, "Helper returned invalid response field")
            .with("field", field)
    }

}
