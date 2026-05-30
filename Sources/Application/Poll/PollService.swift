import Domain

package struct PollService: Sendable {

    let createPoll: any CreatePoll
    let votePoll: any VotePoll
    let unvotePoll: any UnvotePoll
    let getPoll: any GetPoll
    let mutationReadback: any PollMutationReadback
    let mutationPolicy: any MutationPolicy
    let eventStreaming: any DomainEventStreaming
    let eventProjector: PollEventProjector
    let mutationReadbackDelaysNs: [UInt64]

    package init(
        createPoll: any CreatePoll,
        votePoll: any VotePoll,
        unvotePoll: any UnvotePoll,
        getPoll: any GetPoll,
        mutationReadback: any PollMutationReadback,
        mutationPolicy: any MutationPolicy,
        eventStreaming: any DomainEventStreaming,
        eventProjector: PollEventProjector = PollEventProjector(),
        mutationReadbackDelaysNs: [UInt64] = ReadbackRetry.standardDelaysNs
    ) {
        self.createPoll = createPoll
        self.votePoll = votePoll
        self.unvotePoll = unvotePoll
        self.getPoll = getPoll
        self.mutationReadback = mutationReadback
        self.mutationPolicy = mutationPolicy
        self.eventStreaming = eventStreaming
        self.eventProjector = eventProjector
        self.mutationReadbackDelaysNs = mutationReadbackDelaysNs
    }

}
