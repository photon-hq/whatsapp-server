package enum PollChange: Sendable, Equatable {

    case created(Poll)
    case updated(Poll)
    case voteChanged(Poll)
    case choicesChanged(Poll)

}
