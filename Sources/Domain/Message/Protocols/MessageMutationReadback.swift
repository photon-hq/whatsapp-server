package protocol MessageMutationReadback: Sendable {

    func message(
        forMessageId messageId: String
    ) async throws -> MessageSnapshot?

    func sentText(
        matching query: SentTextReadbackQuery
    ) async throws -> MessageSnapshot?

    func sentMedia(
        matching query: SentMediaReadbackQuery
    ) async throws -> MessageSnapshot?

    func sentAttachment(
        matching query: SentAttachmentReadbackQuery
    ) async throws -> MessageSnapshot?

    func sentAttachments(
        matching query: SentAttachmentReadbackQuery,
        limit: Int
    ) async throws -> [MessageSnapshot]

    func receipt(
        forMessageId messageId: String
    ) async throws -> MessageReceiptReadback?

    func reaction(
        matching query: ReactionReadbackQuery
    ) async throws -> MessageReactionReadback?

}
