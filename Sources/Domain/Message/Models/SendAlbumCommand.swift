package struct SendAlbumItem: Sendable, Equatable {

    package let data: [UInt8]
    package let caption: String?
    package let accessibilityText: String?

    package init(
        data: [UInt8],
        caption: String? = nil,
        accessibilityText: String? = nil
    ) {
        self.data = data
        self.caption = caption
        self.accessibilityText = accessibilityText
    }

}

package struct SendAlbumCommand: Sendable, Equatable {

    package let recipient: String
    package let type: MediaType
    package let items: [SendAlbumItem]

    package init(
        recipient: String,
        type: MediaType,
        items: [SendAlbumItem]
    ) {
        self.recipient = recipient
        self.type = type
        self.items = items
    }

}
