import Domain
import Foundation

func serializeTextDocument(
    content: [TextBlock]
) throws -> [String: JSONValue] {
    var spans: [JSONValue] = []
    var blocks: [JSONValue] = []
    var text = ""
    var offset = 0

    for (blockIndex, block) in content.enumerated() {
        if blockIndex > 0 {
            text.append("\n")
            offset += 1
        }

        let blockStart = offset
        let blockText = block.text.map(\.text).joined()
        let blockLength = (blockText as NSString).length

        if block.type != .normal {
            blocks.append(.object([
                "type": .string(helperBlockType(for: block.type)),
                "start": .number(Double(blockStart)),
                "length": .number(Double(blockLength))
            ]))
        }

        for run in block.text {
            let runStart = offset
            let runLength = (run.text as NSString).length
            let spanRange = styledSpanRange(text: run.text, start: runStart)

            if let spanRange {
                for style in run.styles {
                    spans.append(.object([
                        "type": .string(helperStyle(for: style)),
                        "start": .number(Double(spanRange.start)),
                        "length": .number(Double(spanRange.length))
                    ]))
                }
            }

            text.append(run.text)
            offset += runLength
        }
    }

    var payload: [String: JSONValue] = [
        "text": .string(text),
        "parseMode": .string("structured")
    ]

    if !spans.isEmpty { payload["spans"] = .array(spans) }
    if !blocks.isEmpty { payload["blocks"] = .array(blocks) }

    return payload
}


private func styledSpanRange(text: String, start: Int) -> (start: Int, length: Int)? {
    let nsText = text as NSString
    let length = nsText.length
    var leading = 0
    var trailing = length

    while leading < trailing,
          isMarkupBoundaryWhitespace(nsText.character(at: leading)) {
        leading += 1
    }

    while trailing > leading,
          isMarkupBoundaryWhitespace(nsText.character(at: trailing - 1)) {
        trailing -= 1
    }

    guard trailing > leading else {
        return nil
    }

    return (start + leading, trailing - leading)
}

private func isMarkupBoundaryWhitespace(_ codeUnit: unichar) -> Bool {
    guard let scalar = UnicodeScalar(Int(codeUnit)) else {
        return false
    }

    return CharacterSet.whitespacesAndNewlines.contains(scalar)
}

private func helperStyle(for style: TextStyle) -> String {
    switch style {
    case .bold:
        "bold"
    case .italic:
        "italic"
    case .strikethrough:
        "strikethrough"
    case .code:
        "inlineCode"
    }
}

private func helperBlockType(for type: TextBlockType) -> String {
    switch type {
    case .normal:
        "normal"
    case .quote:
        "quote"
    case .bullet:
        "bulletedList"
    case .numbered:
        "numberedList"
    }
}
