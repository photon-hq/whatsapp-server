import Domain
import Foundation

extension MessageService {

    func buildPage(
        from slice: MessagePageSlice,
        scope: MessagePageTokenCodec.Scope,
        pageSize: Int,
        isFromMe: Bool?,
        before: Date?,
        after: Date?,
        recipient: String?
    ) throws -> MessagePage {
        let nextToken = try slice.nextCursor.map {
            try MessagePageTokenCodec.encode(
                MessagePageTokenCodec.payload(
                    scope: scope,
                    snapshotRowId: slice.snapshotRowId,
                    cursor: $0,
                    pageSize: pageSize,
                    isFromMe: isFromMe,
                    before: before,
                    after: after,
                    recipient: recipient
                )
            )
        }

        return MessagePage(
            messages: slice.entries.map(\.message),
            nextPageToken: nextToken
        )
    }

}
