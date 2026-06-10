import Application
import Domain
import GRPCCore
import SwiftProtobuf

struct MessageServiceHandler: PWApp_MessageService.ServiceProtocol {

    let messages: MessageService

    func sendTextMessage(
        request: ServerRequest<PWApp_SendTextMessageRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_MessageResponse> {
        let message = request.message

        let sent = try await messages.sendTextMessage(
            recipient: message.recipient,
            content: try message.content.enumerated().map { index, block in
                try MessageMapper.toDomain(block, index: index)
            },
            replyTo: message.hasReplyTo ? message.replyTo : nil,
            enableLinkPreview: message.enableLinkPreview,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: MessageMapper.toMessageResponse(sent))
    }

    func sendMediaMessage(
        request: ServerRequest<PWApp_SendMediaMessageRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_MessageResponse> {
        let message = request.message
        guard message.hasMedia else {
            throw DomainError(.invalidArgument, "media is required")
                .with("field", "media")
        }
        let media = message.media

        let sent = try await messages.sendMediaMessage(
            recipient: message.recipient,
            type: try MessageMapper.toDomain(media.kind),
            data: Array(media.data),
            caption: media.hasCaption ? media.caption : nil,
            accessibilityText: media.hasAccessibilityText ? media.accessibilityText : nil,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: MessageMapper.toMessageResponse(sent))
    }

    func sendAlbum(
        request: ServerRequest<PWApp_SendAlbumRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_SendAlbumResponse> {
        let message = request.message

        guard let firstKind = message.items.first?.kind else {
            throw DomainError(.invalidArgument, "items must contain 2 to 30 media entries")
                .with("field", "items")
        }

        guard message.items.allSatisfy({ $0.kind == firstKind }) else {
            throw DomainError(.invalidArgument, "all album items must share the same media kind")
                .with("field", "items")
        }

        let sent = try await messages.sendAlbum(
            recipient: message.recipient,
            type: try MessageMapper.toDomain(firstKind),
            items: message.items.map { item in
                (
                    data: Array(item.data),
                    caption: item.hasCaption ? item.caption : nil,
                    accessibilityText: item.hasAccessibilityText ? item.accessibilityText : nil
                )
            },
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        var response = PWApp_SendAlbumResponse()
        response.messages = sent.map(MessageMapper.toProto)

        return ServerResponse(message: response)
    }

    func sendDocument(
        request: ServerRequest<PWApp_SendDocumentRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_MessageResponse> {
        let message = request.message

        let sent = try await messages.sendDocument(
            recipient: message.recipient,
            data: Array(message.data),
            fileName: message.hasFileName ? message.fileName : nil,
            mimeType: message.hasMimeType ? message.mimeType : nil,
            caption: message.hasCaption ? message.caption : nil,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: MessageMapper.toMessageResponse(sent))
    }

    func sendAudio(
        request: ServerRequest<PWApp_SendAudioRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_MessageResponse> {
        let message = request.message

        let sent = try await messages.sendAudio(
            recipient: message.recipient,
            data: Array(message.data),
            mimeType: message.hasMimeType ? message.mimeType : nil,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: MessageMapper.toMessageResponse(sent))
    }

    func sendSticker(
        request: ServerRequest<PWApp_SendStickerRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_MessageResponse> {
        let message = request.message

        let sent = try await messages.sendSticker(
            recipient: message.recipient,
            data: Array(message.data),
            emojis: message.emojis,
            accessibilityText: message.hasAccessibilityText ? message.accessibilityText : nil,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: MessageMapper.toMessageResponse(sent))
    }

    func sendContact(
        request: ServerRequest<PWApp_SendContactRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_MessageResponse> {
        let message = request.message

        let sent = try await messages.sendContact(
            recipient: message.recipient,
            contacts: message.contacts.map(MessageMapper.toDomain),
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: MessageMapper.toMessageResponse(sent))
    }

    func sendReaction(
        request: ServerRequest<PWApp_SendReactionRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_MessageResponse> {
        let message = request.message

        let reacted = try await messages.sendReaction(
            messageId: message.messageID,
            emoji: message.emoji,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: MessageMapper.toMessageResponse(reacted))
    }

    func editMessage(
        request: ServerRequest<PWApp_EditMessageRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_MessageResponse> {
        let message = request.message

        let edited = try await messages.editMessage(
            messageId: message.messageID,
            text: message.text,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: MessageMapper.toMessageResponse(edited))
    }

    func revokeMessage(
        request: ServerRequest<PWApp_RevokeMessageRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_RemoveMessageResponse> {
        let message = request.message

        let removed = try await messages.revokeMessage(
            messageId: message.messageID,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        var response = PWApp_RemoveMessageResponse()
        response.messageID = message.messageID
        response.removed = removed

        return ServerResponse(message: response)
    }

    func deleteMessage(
        request: ServerRequest<PWApp_DeleteMessageRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_RemoveMessageResponse> {
        let message = request.message

        let removed = try await messages.deleteMessage(
            messageId: message.messageID,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        var response = PWApp_RemoveMessageResponse()
        response.messageID = message.messageID
        response.removed = removed

        return ServerResponse(message: response)
    }

    func getMessageStatus(
        request: ServerRequest<PWApp_GetMessageStatusRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_GetMessageStatusResponse> {
        let status = try await messages.getMessageStatus(
            messageId: request.message.messageID
        )

        return ServerResponse(message: MessageMapper.toProto(status))
    }

    func getMessage(
        request: ServerRequest<PWApp_GetMessageRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_MessageResponse> {
        let found = try await messages.getMessage(messageId: request.message.messageID)

        return ServerResponse(message: MessageMapper.toMessageResponse(found))
    }

    func listRecentMessages(
        request: ServerRequest<PWApp_ListRecentMessagesRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_ListMessagesResponse> {
        let message = request.message

        let page = try await messages.listRecentMessages(
            request: RecentMessagesRequest(
                pageSize: message.hasPageSize ? Int(message.pageSize) : nil,
                pageToken: message.hasPageToken ? message.pageToken : nil,
                isFromMe: message.hasIsFromMe ? message.isFromMe : nil,
                before: message.hasBefore ? message.before.date : nil,
                after: message.hasAfter ? message.after.date : nil
            )
        )

        return ServerResponse(message: MessageMapper.toListMessagesResponse(page))
    }

    func listChatMessages(
        request: ServerRequest<PWApp_ListChatMessagesRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_ListMessagesResponse> {
        let message = request.message

        let page = try await messages.listChatMessages(
            request: ChatMessagesRequest(
                recipient: message.recipient,
                pageSize: message.hasPageSize ? Int(message.pageSize) : nil,
                pageToken: message.hasPageToken ? message.pageToken : nil,
                isFromMe: message.hasIsFromMe ? message.isFromMe : nil,
                before: message.hasBefore ? message.before.date : nil,
                after: message.hasAfter ? message.after.date : nil
            )
        )

        return ServerResponse(message: MessageMapper.toListMessagesResponse(page))
    }

    func subscribeMessageEvents(
        request: ServerRequest<PWApp_SubscribeMessageEventsRequest>,
        context: ServerContext
    ) async throws -> StreamingServerResponse<PWApp_SubscribeMessageEventsResponse> {
        let message = request.message

        let stream = try await messages.subscribeEvents(
            recipient: message.hasRecipient ? message.recipient : nil
        )

        return StreamingHeartbeat.response(
            from: stream,
            mapEvent: MessageStreamMapper.toSubscribeProto
        ) {
            var response = PWApp_SubscribeMessageEventsResponse()
            response.payload = .heartbeat(PWApp_Heartbeat())

            return response
        }
    }

}
