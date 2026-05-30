import Domain
import Foundation

enum MessagePageTokenCodec {

    enum Scope: String, Codable {
        case recent
        case chat
    }

    struct Payload: Codable, Equatable {
        let scope: Scope
        let snapshotRowId: Int64
        let cursorSort: Int64
        let cursorRowId: Int64
        let pageSize: Int
        let isFromMe: Bool?
        let beforeMillis: Int64?
        let afterMillis: Int64?
        let recipient: String?
    }

    private static let prefix = "msgpage:"

    static func encode(_ payload: Payload) throws -> String {
        do {
            let data = try JSONEncoder().encode(payload)
            return prefix + data.base64EncodedString()
        } catch {
            throw DomainError(.internalError, "Failed to encode page token")
        }
    }

    static func decode(_ token: String) throws -> Payload {
        guard token.hasPrefix(prefix) else {
            throw invalidPageToken()
        }

        let value = String(token.dropFirst(prefix.count))
        guard let data = Data(base64Encoded: value),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            throw invalidPageToken()
        }

        return payload
    }

    static func cursor(from payload: Payload) -> MessagePageCursor {
        MessagePageCursor(sort: payload.cursorSort, rowId: payload.cursorRowId)
    }

    static func payload(
        scope: Scope,
        snapshotRowId: Int64,
        cursor: MessagePageCursor,
        pageSize: Int,
        isFromMe: Bool?,
        before: Date?,
        after: Date?,
        recipient: String?
    ) -> Payload {
        Payload(
            scope: scope,
            snapshotRowId: snapshotRowId,
            cursorSort: cursor.sort,
            cursorRowId: cursor.rowId,
            pageSize: pageSize,
            isFromMe: isFromMe,
            beforeMillis: millis(from: before),
            afterMillis: millis(from: after),
            recipient: recipient
        )
    }

    static func millis(from date: Date?) -> Int64? {
        guard let date else {
            return nil
        }

        return Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    static func date(fromMillis millis: Int64?) -> Date? {
        guard let millis else {
            return nil
        }

        return Date(timeIntervalSince1970: Double(millis) / 1_000)
    }

    static func invalidPageToken() -> DomainError {
        DomainError(.invalidArgument, "page_token is invalid")
            .with("field", "page_token")
    }

}
