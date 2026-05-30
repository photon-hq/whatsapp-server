import Domain
import Foundation

enum MessagePageInput {

    static func recent(_ request: RecentMessagesRequest) throws -> RecentMessagesQuery {
        let token = try request.pageToken.map {
            try decode($0, scope: .recent)
        }

        let pageSize = try resolvePageSize(request.pageSize, token: token)
        let isFromMe = try resolve(request.isFromMe, tokenValue: token?.isFromMe, hasToken: token != nil)
        let before = try resolveDate(request.before, tokenValue: token?.beforeMillis, hasToken: token != nil)
        let after = try resolveDate(request.after, tokenValue: token?.afterMillis, hasToken: token != nil)

        try TimeInput.validateDateRange(before: before, after: after)

        return RecentMessagesQuery(
            pageSize: pageSize,
            snapshotRowId: token?.snapshotRowId,
            cursor: token.map(MessagePageTokenCodec.cursor),
            isFromMe: isFromMe,
            before: before,
            after: after
        )
    }

    static func chat(_ request: ChatMessagesRequest) throws -> ChatMessagesQuery {
        let token = try request.pageToken.map {
            try decode($0, scope: .chat)
        }

        let recipient = try resolveRecipient(request.recipient, token: token)
        let pageSize = try resolvePageSize(request.pageSize, token: token)
        let isFromMe = try resolve(request.isFromMe, tokenValue: token?.isFromMe, hasToken: token != nil)
        let before = try resolveDate(request.before, tokenValue: token?.beforeMillis, hasToken: token != nil)
        let after = try resolveDate(request.after, tokenValue: token?.afterMillis, hasToken: token != nil)

        try TimeInput.validateDateRange(before: before, after: after)

        return ChatMessagesQuery(
            recipient: recipient,
            pageSize: pageSize,
            snapshotRowId: token?.snapshotRowId,
            cursor: token.map(MessagePageTokenCodec.cursor),
            isFromMe: isFromMe,
            before: before,
            after: after
        )
    }

}

private extension MessagePageInput {

    static func decode(
        _ value: String,
        scope: MessagePageTokenCodec.Scope
    ) throws -> MessagePageTokenCodec.Payload {
        let token = try MessagePageTokenCodec.decode(
            TextInput.trimmedNonEmpty(value, field: "page_token")
        )

        guard token.scope == scope else {
            throw MessagePageTokenCodec.invalidPageToken()
        }

        return token
    }

    static func resolvePageSize(
        _ requested: Int?,
        token: MessagePageTokenCodec.Payload?
    ) throws -> Int {
        guard let token else {
            return try NumberInput.pageSize(requested)
        }

        if let requested, try NumberInput.pageSize(requested) != token.pageSize {
            throw pageTokenMismatch()
        }

        return token.pageSize
    }

    static func resolve<Value: Equatable>(
        _ requested: Value?,
        tokenValue: Value?,
        hasToken: Bool
    ) throws -> Value? {
        guard hasToken else {
            return requested
        }

        if let requested, requested != tokenValue {
            throw pageTokenMismatch()
        }

        return tokenValue
    }

    static func resolveDate(
        _ requested: Date?,
        tokenValue: Int64?,
        hasToken: Bool
    ) throws -> Date? {
        guard hasToken else {
            return requested
        }

        if let requested, MessagePageTokenCodec.millis(from: requested) != tokenValue {
            throw pageTokenMismatch()
        }

        return MessagePageTokenCodec.date(fromMillis: tokenValue)
    }

    static func resolveRecipient(
        _ requested: String,
        token: MessagePageTokenCodec.Payload?
    ) throws -> String {
        let recipient = try RecipientInput.phone(requested)

        if let token {
            guard recipient == token.recipient else {
                throw pageTokenMismatch()
            }
        }

        return recipient
    }

    static func pageTokenMismatch() -> DomainError {
        DomainError(.invalidArgument, "page_token does not match request filters")
            .with("field", "page_token")
    }

}
