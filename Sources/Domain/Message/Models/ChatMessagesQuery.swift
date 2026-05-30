import Foundation

package struct ChatMessagesQuery: Sendable, Hashable {

    package let recipient: String
    package let pageSize: Int
    package let snapshotRowId: Int64?
    package let cursor: MessagePageCursor?
    package let isFromMe: Bool?
    package let before: Date?
    package let after: Date?

    package init(
        recipient: String,
        pageSize: Int,
        snapshotRowId: Int64? = nil,
        cursor: MessagePageCursor? = nil,
        isFromMe: Bool? = nil,
        before: Date? = nil,
        after: Date? = nil
    ) {
        self.recipient = recipient
        self.pageSize = pageSize
        self.snapshotRowId = snapshotRowId
        self.cursor = cursor
        self.isFromMe = isFromMe
        self.before = before
        self.after = after
    }

}
