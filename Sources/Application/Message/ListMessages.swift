import Domain

package extension MessageService {

    func listRecentMessages(
        request: RecentMessagesRequest = RecentMessagesRequest()
    ) async throws -> MessagePage {
        let query = try MessagePageInput.recent(request)
        let slice = try await messageQuerying.listRecentMessages(query: query)

        return try buildPage(
            from: slice,
            scope: MessagePageTokenCodec.Scope.recent,
            pageSize: query.pageSize,
            isFromMe: query.isFromMe,
            before: query.before,
            after: query.after,
            recipient: nil as String?
        )
    }

    func listChatMessages(request: ChatMessagesRequest) async throws -> MessagePage {
        let query = try MessagePageInput.chat(request)
        let slice = try await messageQuerying.listChatMessages(query: query)

        return try buildPage(
            from: slice,
            scope: MessagePageTokenCodec.Scope.chat,
            pageSize: query.pageSize,
            isFromMe: query.isFromMe,
            before: query.before,
            after: query.after,
            recipient: query.recipient
        )
    }
}
