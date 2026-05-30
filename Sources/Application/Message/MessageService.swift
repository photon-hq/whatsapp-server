import Domain

package struct MessageService: Sendable {

    let sendTextMessage: any SendTextMessage
    let sendMediaMessage: any SendMediaMessage
    let sendReaction: any SendReaction
    let messageQuerying: any MessageQuerying
    let mutationReadback: any MessageMutationReadback
    let mutationPolicy: any MutationPolicy
    let eventStreaming: any DomainEventStreaming
    let eventProjector: MessageEventProjector
    let mutationReadbackDelaysNs: [UInt64]

    package init(
        sendTextMessage: any SendTextMessage,
        sendMediaMessage: any SendMediaMessage,
        sendReaction: any SendReaction,
        messageQuerying: any MessageQuerying,
        mutationReadback: any MessageMutationReadback,
        mutationPolicy: any MutationPolicy,
        eventStreaming: any DomainEventStreaming,
        eventProjector: MessageEventProjector = MessageEventProjector(),
        mutationReadbackDelaysNs: [UInt64] = ReadbackRetry.standardDelaysNs
    ) {
        self.sendTextMessage = sendTextMessage
        self.sendMediaMessage = sendMediaMessage
        self.sendReaction = sendReaction
        self.messageQuerying = messageQuerying
        self.mutationReadback = mutationReadback
        self.mutationPolicy = mutationPolicy
        self.eventStreaming = eventStreaming
        self.eventProjector = eventProjector
        self.mutationReadbackDelaysNs = mutationReadbackDelaysNs
    }

}
