package enum CaughtUpDomainEvent: Sendable, Equatable {

    case message(SequencedMessageChange)
    case poll(SequencedPollChange)

}
