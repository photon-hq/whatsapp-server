import Domain

package struct MessageService: Sendable {

    let sendTextMessage: any SendTextMessage
    let sendMediaMessage: any SendMediaMessage
    let sendAlbum: any SendAlbum
    let sendDocument: any SendDocument
    let sendAudio: any SendAudio
    let sendSticker: any SendSticker
    let sendContact: any SendContact
    let sendReaction: any SendReaction
    let editMessage: any EditMessage
    let revokeMessage: any RevokeMessage
    let deleteMessage: any DeleteMessage
    let messageStatusQuerying: any MessageStatusQuerying
    let messageQuerying: any MessageQuerying
    let mutationReadback: any MessageMutationReadback
    let mutationPolicy: any MutationPolicy
    let eventStreaming: any DomainEventStreaming
    let eventProjector: MessageEventProjector
    let mutationReadbackDelaysNs: [UInt64]

    package init(
        sendTextMessage: any SendTextMessage,
        sendMediaMessage: any SendMediaMessage,
        sendAlbum: any SendAlbum,
        sendDocument: any SendDocument,
        sendAudio: any SendAudio,
        sendSticker: any SendSticker,
        sendContact: any SendContact,
        sendReaction: any SendReaction,
        editMessage: any EditMessage,
        revokeMessage: any RevokeMessage,
        deleteMessage: any DeleteMessage,
        messageStatusQuerying: any MessageStatusQuerying,
        messageQuerying: any MessageQuerying,
        mutationReadback: any MessageMutationReadback,
        mutationPolicy: any MutationPolicy,
        eventStreaming: any DomainEventStreaming,
        eventProjector: MessageEventProjector = MessageEventProjector(),
        mutationReadbackDelaysNs: [UInt64] = ReadbackRetry.standardDelaysNs
    ) {
        self.sendTextMessage = sendTextMessage
        self.sendMediaMessage = sendMediaMessage
        self.sendAlbum = sendAlbum
        self.sendDocument = sendDocument
        self.sendAudio = sendAudio
        self.sendSticker = sendSticker
        self.sendContact = sendContact
        self.sendReaction = sendReaction
        self.editMessage = editMessage
        self.revokeMessage = revokeMessage
        self.deleteMessage = deleteMessage
        self.messageStatusQuerying = messageStatusQuerying
        self.messageQuerying = messageQuerying
        self.mutationReadback = mutationReadback
        self.mutationPolicy = mutationPolicy
        self.eventStreaming = eventStreaming
        self.eventProjector = eventProjector
        self.mutationReadbackDelaysNs = mutationReadbackDelaysNs
    }

}
