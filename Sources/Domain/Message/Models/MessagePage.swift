package struct MessagePageCursor: Sendable, Hashable {

    package let sort: Int64
    package let rowId: Int64

    package init(sort: Int64, rowId: Int64) {
        self.sort = sort
        self.rowId = rowId
    }

}

package struct MessagePageEntry: Sendable, Equatable {

    package let message: MessageSnapshot
    package let cursor: MessagePageCursor

    package init(message: MessageSnapshot, cursor: MessagePageCursor) {
        self.message = message
        self.cursor = cursor
    }

}

package struct MessagePageSlice: Sendable, Equatable {

    package let entries: [MessagePageEntry]
    package let snapshotRowId: Int64
    package let nextCursor: MessagePageCursor?

    package init(
        entries: [MessagePageEntry],
        snapshotRowId: Int64,
        nextCursor: MessagePageCursor?
    ) {
        self.entries = entries
        self.snapshotRowId = snapshotRowId
        self.nextCursor = nextCursor
    }

}

package struct MessagePage: Sendable, Equatable {

    package let messages: [MessageSnapshot]
    package let nextPageToken: String?

    package init(messages: [MessageSnapshot], nextPageToken: String?) {
        self.messages = messages
        self.nextPageToken = nextPageToken
    }

}
