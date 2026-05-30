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
