import Foundation

package struct ChatMessagesRequest: Sendable, Hashable {

    package let recipient: String
    package let pageSize: Int?
    package let pageToken: String?
    package let isFromMe: Bool?
    package let before: Date?
    package let after: Date?

    package init(
        recipient: String,
        pageSize: Int? = nil,
        pageToken: String? = nil,
        isFromMe: Bool? = nil,
        before: Date? = nil,
        after: Date? = nil
    ) {
        self.recipient = recipient
        self.pageSize = pageSize
        self.pageToken = pageToken
        self.isFromMe = isFromMe
        self.before = before
        self.after = after
    }

}
