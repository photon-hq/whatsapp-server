package struct SendTextMessageCommand: Sendable, Equatable {

    package let recipient: String
    package let content: [TextBlock]
    package let replyTo: String?
    package let enableLinkPreview: Bool

    package init(
        recipient: String,
        content: [TextBlock],
        replyTo: String? = nil,
        enableLinkPreview: Bool = false
    ) {
        self.recipient = recipient
        self.content = content
        self.replyTo = replyTo
        self.enableLinkPreview = enableLinkPreview
    }

    package var text: String {
        TextContent.plainText(content)
    }

}
