package enum DomainEvent: Sendable, Equatable {

    case message(MessageDomainEvent)
    case poll(PollDomainEvent)

    package var label: String {
        switch self {
        case .message(let event):
            switch event {
            case .changed:
                "message.changed"
            }
        case .poll(let event):
            switch event {
            case .changed:
                "poll.changed"
            }
        }
    }

}
