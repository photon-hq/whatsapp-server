package enum MessageDeliveryStatus: String, Sendable, Equatable {

    case pending
    case sent
    case delivered
    case read
    case played
    case error
    case unknown

}

package struct MessageDeliveryStatusSnapshot: Sendable, Equatable {

    package let messageId: String
    package let status: MessageDeliveryStatus
    package let statusCode: Int
    package let isFromMe: Bool
    package let isSent: Bool
    package let isError: Bool
    package let isPlayed: Bool
    package let text: String

    package init(
        messageId: String,
        status: MessageDeliveryStatus,
        statusCode: Int,
        isFromMe: Bool,
        isSent: Bool,
        isError: Bool,
        isPlayed: Bool,
        text: String
    ) {
        self.messageId = messageId
        self.status = status
        self.statusCode = statusCode
        self.isFromMe = isFromMe
        self.isSent = isSent
        self.isError = isError
        self.isPlayed = isPlayed
        self.text = text
    }

}
