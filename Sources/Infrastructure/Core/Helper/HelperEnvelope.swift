struct HelperRequest: Encodable {

    let transactionId: String
    let action: String
    let data: [String: JSONValue]

}


struct HelperResponse: Decodable {

    let transactionId: String?
    let success: Bool
    let error: HelperResponseError?
    let payload: [String: JSONValue]

    private enum CodingKeys: String, CodingKey {
        case transactionId
        case success
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var payload: [String: JSONValue] = [:]

        for key in container.allKeys where !Self.envelopeKeys.contains(key.stringValue) {
            payload[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }

        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.transactionId = try keyed.decodeIfPresent(String.self, forKey: .transactionId)
        self.success = try keyed.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.error = try keyed.decodeIfPresent(HelperResponseError.self, forKey: .error)
        self.payload = payload
    }

    private static let envelopeKeys = Set(["transactionId", "success", "error"])

}


struct HelperResponseError: Decodable {

    let code: String
    let message: String

}


private struct DynamicCodingKey: CodingKey {

    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }

}
