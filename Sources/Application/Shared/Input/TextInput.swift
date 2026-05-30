import Domain
import Foundation

enum TextInput {

    static func trim(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func trimmedNonEmpty(
        _ value: String,
        field: String
    ) throws -> String {
        let trimmed = trim(value)

        guard !trimmed.isEmpty else {
            throw DomainError(.invalidArgument, "\(field) must not be empty")
                .with("field", field)
        }

        return trimmed
    }

    static func textContent(_ blocks: [TextBlock]) throws -> [TextBlock] {
        guard !blocks.isEmpty else {
            throw DomainError(.invalidArgument, "content must not be empty")
                .with("field", "content")
        }

        for (blockIndex, block) in blocks.enumerated() {
            let blockField = "content[\(blockIndex)]"
            guard !block.text.isEmpty else {
                throw DomainError(.invalidArgument, "\(blockField).text must not be empty")
                    .with("field", "\(blockField).text")
            }

            for (runIndex, run) in block.text.enumerated() {
                let runField = "\(blockField).text[\(runIndex)]"
                guard !run.text.isEmpty else {
                    throw DomainError(.invalidArgument, "\(runField).text must not be empty")
                        .with("field", "\(runField).text")
                }
            }
        }

        guard !trim(TextContent.plainText(blocks)).isEmpty else {
            throw DomainError(.invalidArgument, "content must not be blank")
                .with("field", "content")
        }

        return blocks.map { block in
            TextBlock(
                type: block.type,
                text: block.text.map { run in
                    TextRun(text: run.text, styles: unique(run.styles))
                }
            )
        }
    }

    static func optional(
        _ value: String?,
        field: String
    ) throws -> String? {
        guard let value else {
            return nil
        }

        guard !trim(value).isEmpty else {
            throw DomainError(.invalidArgument, "\(field) must not be empty")
                .with("field", field)
        }

        return value
    }

    private static func unique(_ styles: [TextStyle]) -> [TextStyle] {
        var seen: Set<TextStyle> = []
        var result: [TextStyle] = []
        for style in styles where !seen.contains(style) {
            seen.insert(style)
            result.append(style)
        }
        return result
    }
}
