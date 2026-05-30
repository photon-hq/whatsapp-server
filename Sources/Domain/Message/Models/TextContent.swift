package struct TextBlock: Sendable, Hashable {

    package let type: TextBlockType

    package let text: [TextRun]

    package init(type: TextBlockType = .normal, text: [TextRun]) {
        self.type = type
        self.text = text
    }

}

package struct TextRun: Sendable, Hashable {

    package let text: String

    package let styles: [TextStyle]

    package init(text: String, styles: [TextStyle] = []) {
        self.text = text
        self.styles = styles
    }

}

package enum TextContent {

    package static func plainText(_ blocks: [TextBlock]) -> String {
        blocks
            .map { block in
                block.text.map(\.text).joined()
            }
            .joined(separator: "\n")
    }

}
