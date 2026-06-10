import Domain
import Foundation

private let albumItemRange = 2...30

package extension MessageService {

    func sendAlbum(
        recipient: String,
        type: MediaType,
        items: [(data: [UInt8], caption: String?, accessibilityText: String?)],
        clientMessageId: String? = nil
    ) async throws -> [MessageSnapshot] {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)

        guard albumItemRange.contains(items.count) else {
            throw DomainError(.invalidArgument, "items must contain 2 to 30 media entries")
                .with("field", "items")
        }

        for (index, item) in items.enumerated() where item.data.isEmpty {
            throw DomainError(.invalidArgument, "item data is required")
                .with("field", "items[\(index)].data")
        }

        let command = SendAlbumCommand(
            recipient: try RecipientInput.phone(recipient),
            type: type,
            items: try items.enumerated().map { index, item in
                SendAlbumItem(
                    data: item.data,
                    caption: try TextInput.optional(
                        item.caption,
                        field: "items[\(index)].caption"
                    ),
                    accessibilityText: try TextInput.optional(
                        item.accessibilityText,
                        field: "items[\(index)].accessibility_text"
                    )
                )
            }
        )
        let startedAt = Date()
        let expectedCount = command.items.count
        let kind: MessageAttachmentKind = type == .video ? .video : .image

        return try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await sendAlbum.sendAlbum(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: { () async throws -> [MessageSnapshot]? in
                    let snapshots = try await mutationReadback.sentAttachments(
                        matching: SentAttachmentReadbackQuery(
                            recipient: command.recipient,
                            kind: kind,
                            notBefore: startedAt
                        ),
                        limit: expectedCount
                    )

                    return snapshots.count >= expectedCount ? snapshots : nil
                }
            ) else {
                throw DomainError(.timeout, "Sent album items did not become visible in ChatStorage in time")
                    .with("recipient", command.recipient)
            }

            return readback
        }
    }

}
