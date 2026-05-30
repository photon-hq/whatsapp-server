import Domain
import Foundation

enum WhatsAppPollSnapshotParser {

    static func parse(
        pollId: String,
        metadata: Data?,
        receiptInfo: Data?
    ) -> Poll? {
        if let receiptInfo,
           let poll = parseReceiptInfo(
            pollId: pollId,
            receiptInfo: receiptInfo
           ) {
            return poll
        }

        if let metadata {
            return parseMetadata(
                pollId: pollId,
                metadata: metadata
            )
        }

        return nil
    }

    static func parseMetadata(
        pollId: String,
        metadata: Data
    ) -> Poll? {
        var reader = ProtoReader(metadata)
        var best: Poll?

        while let field = reader.nextField() {
            guard field.number == 9,
                  case .lengthDelimited(let envelope) = field.value
            else {
                continue
            }

            if let poll = parseEnvelope(
                pollId: pollId,
                data: envelope
            ) {
                best = poll
            }
        }

        return best
    }

    static func parseReceiptInfo(
        pollId: String,
        receiptInfo: Data
    ) -> Poll? {
        var reader = ProtoReader(receiptInfo)
        var best: Poll?

        while let field = reader.nextField() {
            guard field.number == 8,
                  case .lengthDelimited(let pollData) = field.value
            else {
                continue
            }

            if let poll = parsePoll(
                pollId: pollId,
                data: pollData
            ) {
                best = poll
            }
        }

        return best
    }

    private static func parseEnvelope(
        pollId: String,
        data: Data
    ) -> Poll? {
        var reader = ProtoReader(data)

        while let field = reader.nextField() {
            guard field.number == 119,
                  case .lengthDelimited(let pollData) = field.value
            else {
                continue
            }

            return parsePoll(
                pollId: pollId,
                data: pollData
            )
        }

        return nil
    }

    private static func parsePoll(
        pollId: String,
        data: Data
    ) -> Poll? {
        var reader = ProtoReader(data)
        var question: String?
        var optionTexts: [String] = []
        var selectableOptionsCount: UInt64?
        var voteIndexes: [Int] = []
        var hideVoterNames = false

        while let field = reader.nextField() {
            switch (field.number, field.value) {
            case (2, .lengthDelimited(let value)):
                question = String(data: value, encoding: .utf8)

            case (3, .lengthDelimited(let value)):
                if let option = parseOption(data: value) {
                    optionTexts.append(option)
                }

            case (4, .varint(let value)):
                selectableOptionsCount = value

            case (6, .lengthDelimited(let value)):
                voteIndexes.append(contentsOf: parseVoteIndexes(data: value))

            case (15, .varint(let value)):
                hideVoterNames = value != 0

            default:
                continue
            }
        }

        guard let question,
              !question.isEmpty,
              optionTexts.count >= 2
        else {
            return nil
        }

        var voteCounts = Array(repeating: 0, count: optionTexts.count)
        for index in voteIndexes where voteCounts.indices.contains(index) {
            voteCounts[index] += 1
        }

        return Poll(
            pollId: pollId,
            question: question,
            choices: optionTexts.enumerated().map { index, text in
                PollChoice(index: index, text: text, voteCount: voteCounts[index])
            },
            allowMultipleChoices: selectableOptionsCount.map { $0 == 0 || $0 > 1 } ?? false,
            hideVoterNames: hideVoterNames
        )
    }

    private static func parseOption(data: Data) -> String? {
        var reader = ProtoReader(data)

        while let field = reader.nextField() {
            guard field.number == 1,
                  case .lengthDelimited(let value) = field.value
            else {
                continue
            }

            return String(data: value, encoding: .utf8)
        }

        return nil
    }

    private static func parseVoteIndexes(data: Data) -> [Int] {
        var reader = ProtoReader(data)
        var indexes: [Int] = []

        while let field = reader.nextField() {
            guard field.number == 1,
                  case .varint(let value) = field.value,
                  value <= UInt64(Int.max)
            else {
                continue
            }

            indexes.append(Int(value))
        }

        return indexes
    }

}

private struct ProtoReader {

    enum FieldValue {
        case varint(UInt64)
        case fixed64(UInt64)
        case lengthDelimited(Data)
        case fixed32(UInt32)
    }

    struct Field {
        let number: Int
        let value: FieldValue
    }

    private let bytes: [UInt8]
    private var offset = 0

    init(_ data: Data) {
        self.bytes = Array(data)
    }

    mutating func nextField() -> Field? {
        guard let key = readVarint() else {
            return nil
        }

        let fieldNumber = Int(key >> 3)
        let wireType = Int(key & 0x07)
        guard fieldNumber > 0 else {
            return nil
        }

        switch wireType {
        case 0:
            guard let value = readVarint() else {
                return nil
            }
            return Field(number: fieldNumber, value: .varint(value))

        case 1:
            guard let value = readFixed64() else {
                return nil
            }
            return Field(number: fieldNumber, value: .fixed64(value))

        case 2:
            guard let length = readVarint(),
                  length <= UInt64(bytes.count - offset)
            else {
                return nil
            }

            let end = offset + Int(length)
            let data = Data(bytes[offset..<end])
            offset = end
            return Field(number: fieldNumber, value: .lengthDelimited(data))

        case 5:
            guard let value = readFixed32() else {
                return nil
            }
            return Field(number: fieldNumber, value: .fixed32(value))

        default:
            return nil
        }
    }

    private mutating func readVarint() -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0

        while offset < bytes.count, shift < 64 {
            let byte = bytes[offset]
            offset += 1

            result |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                return result
            }

            shift += 7
        }

        return nil
    }

    private mutating func readFixed32() -> UInt32? {
        guard offset + 4 <= bytes.count else {
            return nil
        }

        var value: UInt32 = 0
        for index in 0..<4 {
            value |= UInt32(bytes[offset + index]) << UInt32(index * 8)
        }
        offset += 4

        return value
    }

    private mutating func readFixed64() -> UInt64? {
        guard offset + 8 <= bytes.count else {
            return nil
        }

        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(bytes[offset + index]) << UInt64(index * 8)
        }
        offset += 8

        return value
    }

}
