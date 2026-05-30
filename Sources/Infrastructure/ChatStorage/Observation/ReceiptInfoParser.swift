import Foundation

enum ReceiptInfoParser {

    static func lastEmoji(inHex hex: String) -> String? {
        let text = String(decoding: HexBytes.decode(hex), as: UTF8.self)
        return text
            .filter(isEmoji)
            .last
            .map(String.init)
    }

    static func lastLid(inHex hex: String) -> String? {
        lastMatch(
            pattern: #"[0-9]{5,}@lid"#,
            in: String(decoding: HexBytes.decode(hex), as: UTF8.self)
        )
    }

    static func lastStanzaId(inHex hex: String) -> String? {
        lastMatch(
            pattern: #"[A-F0-9]{16,}"#,
            in: String(decoding: HexBytes.decode(hex), as: UTF8.self)
        )
    }

    private static func isEmoji(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            scalar.value > 0x7F
                && (scalar.properties.isEmoji || scalar.properties.isEmojiPresentation)
        }
        || character.unicodeScalars.contains { $0.properties.isEmoji }
            && character.unicodeScalars.contains { $0.value == 0x20E3 }
    }

    private static func lastMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).last.flatMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

}
