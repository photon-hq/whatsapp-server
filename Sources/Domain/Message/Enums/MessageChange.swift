package enum MessageChange: Sendable, Equatable {

    case text(MessageText)
    case attachment(MessageAttachment)
    case reaction(MessageReaction)
    case receipt(MessageReceiptUpdate)

}
