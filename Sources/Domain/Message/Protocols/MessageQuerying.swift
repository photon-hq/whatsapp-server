package protocol MessageQuerying: Sendable {

    func getMessage(messageId: String) async throws -> MessageSnapshot?

    func listRecentMessages(query: RecentMessagesQuery) async throws -> MessagePageSlice

    func listChatMessages(query: ChatMessagesQuery) async throws -> MessagePageSlice

}
