package struct SendDocumentCommand: Sendable, Equatable {

    package let recipient: String
    package let data: [UInt8]
    package let fileName: String?
    package let mimeType: String?
    package let caption: String?

    package init(
        recipient: String,
        data: [UInt8],
        fileName: String? = nil,
        mimeType: String? = nil,
        caption: String? = nil
    ) {
        self.recipient = recipient
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
        self.caption = caption
    }

}
