import CryptoKit
import Foundation

enum SHA256Hex {

    static func string(_ value: String) -> String {
        string(Data(value.utf8))
    }

    static func string(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

}
