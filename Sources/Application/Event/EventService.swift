import Domain

package struct EventService: Sendable {

    let eventStreaming: any DomainEventStreaming
    let messageProjector: MessageEventProjector
    let pollProjector: PollEventProjector

    package init(
        eventStreaming: any DomainEventStreaming,
        messageProjector: MessageEventProjector,
        pollProjector: PollEventProjector = PollEventProjector()
    ) {
        self.eventStreaming = eventStreaming
        self.messageProjector = messageProjector
        self.pollProjector = pollProjector
    }

}
