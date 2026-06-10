import Domain
import Foundation
import GRDB

struct ChatStorageChatSessionRecord: Decodable, FetchableRecord, Sendable {

    let rowId: Int64
    let contactJid: String
    let partnerName: String?

    enum CodingKeys: String, CodingKey {
        case rowId
        case contactJid
        case partnerName
    }

    func matches(recipient: String) -> Bool {
        ChatStorageRecipient(
            contactJid: contactJid,
            partnerName: partnerName
        ).matches(recipient)
    }

}

struct ChatStorageMessageRecord: Decodable, FetchableRecord, Sendable {

    let rowId: Int64
    let sort: Int64
    let chatSessionId: Int64
    let contactJid: String
    let partnerName: String?
    let stanzaId: String
    let isFromMe: Bool
    let messageType: Int
    let messageStatus: Int?
    let messageErrorStatus: Int?
    let sentDate: Double?
    let messageDate: Double?
    let text: String?
    let fromJid: String?
    let toJid: String?
    let pushName: String?
    let mediaTitle: String?
    let mediaUrl: String?
    let mediaLocalPath: String?
    let mediaFileSize: Int64?
    let mediaVCardName: String?
    let mediaVCardString: String?
    let mediaLatitude: Double?
    let mediaLongitude: Double?
    let mediaThumbnailLocalPath: String?
    let mediaXmppThumbnailPath: String?
    let mediaUrlDate: Double?
    let mediaCloudStatus: Int?
    let parentContactJid: String?
    let parentStanzaId: String?
    let parentIsFromMe: Bool?
    let receiptHex: String?

    enum CodingKeys: String, CodingKey {
        case rowId
        case sort
        case chatSessionId
        case contactJid
        case partnerName
        case stanzaId
        case isFromMe
        case messageType
        case messageStatus
        case messageErrorStatus
        case sentDate
        case messageDate
        case text
        case fromJid
        case toJid
        case pushName
        case mediaTitle
        case mediaUrl
        case mediaLocalPath
        case mediaFileSize
        case mediaVCardName
        case mediaVCardString
        case mediaLatitude
        case mediaLongitude
        case mediaThumbnailLocalPath
        case mediaXmppThumbnailPath
        case mediaUrlDate
        case mediaCloudStatus
        case parentContactJid
        case parentStanzaId
        case parentIsFromMe
        case receiptHex
    }

    static let selectSQL = """
        SELECT
            m.Z_PK AS rowId,
            m.ZSORT AS sort,
            m.ZCHATSESSION AS chatSessionId,
            c.ZCONTACTJID AS contactJid,
            c.ZPARTNERNAME AS partnerName,
            m.ZSTANZAID AS stanzaId,
            m.ZISFROMME AS isFromMe,
            m.ZMESSAGETYPE AS messageType,
            m.ZMESSAGESTATUS AS messageStatus,
            m.ZMESSAGEERRORSTATUS AS messageErrorStatus,
            m.ZSENTDATE AS sentDate,
            m.ZMESSAGEDATE AS messageDate,
            m.ZTEXT AS text,
            m.ZFROMJID AS fromJid,
            m.ZTOJID AS toJid,
            m.ZPUSHNAME AS pushName,
            media.ZTITLE AS mediaTitle,
            media.ZMEDIAURL AS mediaUrl,
            media.ZMEDIALOCALPATH AS mediaLocalPath,
            media.ZFILESIZE AS mediaFileSize,
            media.ZVCARDNAME AS mediaVCardName,
            media.ZVCARDSTRING AS mediaVCardString,
            media.ZLATITUDE AS mediaLatitude,
            media.ZLONGITUDE AS mediaLongitude,
            media.ZTHUMBNAILLOCALPATH AS mediaThumbnailLocalPath,
            media.ZXMPPTHUMBPATH AS mediaXmppThumbnailPath,
            media.ZMEDIAURLDATE AS mediaUrlDate,
            media.ZCLOUDSTATUS AS mediaCloudStatus,
            COALESCE(pc.ZCONTACTJID, qpc.ZCONTACTJID) AS parentContactJid,
            COALESCE(p.ZSTANZAID, qp.ZSTANZAID) AS parentStanzaId,
            COALESCE(p.ZISFROMME, qp.ZISFROMME) AS parentIsFromMe,
            hex(info.ZRECEIPTINFO) AS receiptHex
        FROM ZWAMESSAGE m
        JOIN ZWACHATSESSION c ON c.Z_PK = m.ZCHATSESSION
        LEFT JOIN ZWAMESSAGE p ON p.Z_PK = m.ZPARENTMESSAGE
        LEFT JOIN ZWACHATSESSION pc ON pc.Z_PK = p.ZCHATSESSION
        LEFT JOIN ZWAMEDIAITEM media ON media.Z_PK = m.ZMEDIAITEM
        LEFT JOIN ZWAMESSAGE qp
          ON p.Z_PK IS NULL
         AND qp.ZCHATSESSION = m.ZCHATSESSION
         AND qp.Z_PK != m.Z_PK
         AND qp.ZSTANZAID IS NOT NULL
         AND qp.ZSTANZAID != ''
         AND media.ZMETADATA IS NOT NULL
         AND instr(media.ZMETADATA, CAST(qp.ZSTANZAID AS BLOB)) > 0
        LEFT JOIN ZWACHATSESSION qpc ON qpc.Z_PK = qp.ZCHATSESSION
        LEFT JOIN ZWAMESSAGEINFO info ON info.Z_PK = m.ZMESSAGEINFO

        """

    var messageId: String {
        "\(contactJid)_\(stanzaId)_\(isFromMe ? 1 : 0)_0"
    }

    var cursor: MessagePageCursor {
        MessagePageCursor(sort: sort, rowId: rowId)
    }

    var snapshot: MessageSnapshot {
        MessageSnapshot(
            messageId: messageId,
            recipient: recipient,
            chatJid: contactJid,
            partnerName: partnerName,
            stanzaId: stanzaId,
            isFromMe: isFromMe,
            messageType: messageType,
            messageStatus: messageStatus,
            messageErrorStatus: messageErrorStatus,
            text: text ?? mediaTitle ?? "",
            messageDate: WhatsAppDate.fromStoredSeconds(messageDate),
            sentDate: WhatsAppDate.fromStoredSeconds(sentDate),
            fromJid: fromJid,
            toJid: toJid,
            pushName: pushName,
            replyToMessageId: replyToMessageId,
            media: media,
            latestReaction: latestReaction,
            receiptDigest: receiptDigest
        )
    }

    var recipient: String {
        ChatStorageRecipient(
            contactJid: contactJid,
            partnerName: partnerName
        ).publicValue
    }

    var replyToMessageId: String? {
        guard let parentContactJid,
              let parentStanzaId,
              let parentIsFromMe
        else {
            return nil
        }

        return "\(parentContactJid)_\(parentStanzaId)_\(parentIsFromMe ? 1 : 0)_0"
    }

    func matches(recipient: String) -> Bool {
        ChatStorageRecipient(
            contactJid: contactJid,
            partnerName: partnerName
        ).matches(recipient)
    }

    var recipientCanMatchByPhone: Bool {
        ChatStorageRecipient(
            contactJid: contactJid,
            partnerName: partnerName
        ).canMatchByPhone
    }

    func mediaCaptionMatches(_ caption: String?) -> Bool {
        guard let caption, !caption.isEmpty else {
            return true
        }

        return text == caption || mediaTitle == caption
    }

    func vcardNameMatches(_ expected: String?) -> Bool {
        guard let expected, !expected.isEmpty else {
            return true
        }

        return mediaVCardName == expected
    }

    func matches(replyToMessageId expected: String?) -> Bool {
        guard let expected else {
            return true
        }

        return replyToMessageId == expected
    }

    var hasSuccessfulSendSignal: Bool {
        guard isFromMe,
              messageErrorStatus == 0,
              let messageStatus
        else {
            return false
        }

        return messageStatus == 1 || messageStatus == 6 || messageStatus == 8
    }

    var hasUploadedMedia: Bool {
        guard let mediaUrl else {
            return false
        }

        return !mediaUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasContactData: Bool {
        guard let vcard = nonEmpty(mediaVCardString) else {
            return false
        }

        return vcard.hasPrefix("BEGIN:VCARD")
    }

    /// Treats audio and voice (PTT) as equivalent: the helper's `send-audio`
    /// always sends a voice note but ChatStorage may classify it as either.
    func attachmentKindMatches(_ kind: MessageAttachmentKind) -> Bool {
        let actual = attachmentKind
        if actual == kind {
            return true
        }

        let audioLike: Set<MessageAttachmentKind> = [.audio, .voice]
        return audioLike.contains(actual) && audioLike.contains(kind)
    }

    /// Operation-specific "this attachment was accepted" signal. Uploaded media
    /// (mediaUrl) for binary attachments; vCard payload for contact cards.
    func attachmentReady(for kind: MessageAttachmentKind) -> Bool {
        switch kind {
        case .contact:
            return hasContactData
        default:
            return hasUploadedMedia
        }
    }

    var hasSuccessfulMediaSendSignal: Bool {
        hasSuccessfulSendSignal && hasUploadedMedia
    }

    private var media: MessageMediaSnapshot? {
        guard hasMediaData else {
            return nil
        }

        return MessageMediaSnapshot(
            kind: attachmentKind,
            title: nonEmpty(mediaTitle),
            localPath: nonEmpty(mediaLocalPath),
            mediaUrl: nonEmpty(mediaUrl),
            fileSize: mediaFileSize.map { $0 > 0 ? $0 : nil } ?? nil,
            vcardName: nonEmpty(mediaVCardName),
            vcardString: nonEmpty(mediaVCardString),
            latitude: mediaLatitude,
            longitude: mediaLongitude,
            thumbnailLocalPath: nonEmpty(mediaThumbnailLocalPath),
            xmppThumbnailPath: nonEmpty(mediaXmppThumbnailPath),
            mediaUrlDate: WhatsAppDate.fromStoredSeconds(mediaUrlDate),
            cloudStatus: mediaCloudStatus
        )
    }

    private var latestReaction: MessageReactionSnapshot? {
        guard let receiptHex,
              receiptHex.contains("3A"),
              let emoji = ReceiptInfoParser.lastEmoji(inHex: receiptHex)
        else {
            return nil
        }

        return MessageReactionSnapshot(
            messageId: messageId,
            emoji: emoji,
            actorJid: ReceiptInfoParser.lastLid(inHex: receiptHex),
            reactionId: ReceiptInfoParser.lastStanzaId(inHex: receiptHex)
        )
    }

    private var receiptDigest: String? {
        guard let receiptHex,
              !receiptHex.isEmpty
        else {
            return nil
        }

        return SHA256Hex.string(receiptHex)
    }

    private var hasMediaData: Bool {
        nonEmpty(mediaTitle) != nil
            || nonEmpty(mediaUrl) != nil
            || nonEmpty(mediaLocalPath) != nil
            || nonEmpty(mediaVCardName) != nil
            || nonEmpty(mediaVCardString) != nil
            || mediaFileSize.map { $0 > 0 } == true
            || hasLocationMetadata
    }

    private var attachmentKind: MessageAttachmentKind {
        switch messageType {
        case 1:
            return .image
        case 2:
            return .video
        case 3:
            return .audio
        case 4:
            return .contact
        case 5:
            return .location
        default:
            break
        }

        if let path = mediaLocalPath?.lowercased(), !path.isEmpty {
            if path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") || path.hasSuffix(".png") || path.hasSuffix(".heic") || path.hasSuffix(".gif") {
                return .image
            }

            if path.hasSuffix(".mp4") || path.hasSuffix(".mov") {
                return .video
            }

            if path.hasSuffix(".opus") || path.hasSuffix(".m4a") || path.hasSuffix(".aac") || path.hasSuffix(".mp3") {
                return .audio
            }

            if path.hasSuffix(".webp") {
                return .sticker
            }
        }

        // ZVCARDNAME doubles as a media-hash column on document/media rows, so
        // only treat the row as a contact card when an actual vCard payload is
        // present (real contact sends also carry ZMESSAGETYPE == 4).
        if hasContactData {
            return .contact
        }

        if hasLocationMetadata {
            return .location
        }

        return .document
    }

    private var hasLocationMetadata: Bool {
        guard let mediaLatitude,
              let mediaLongitude
        else {
            return false
        }

        return mediaLatitude != 0 || mediaLongitude != 0
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return value
    }

}

struct ChatStorageMessageKey: Sendable {

    let contactJid: String
    let stanzaId: String
    let isFromMe: Bool

    init?(messageId: String) {
        let parts = messageId.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count >= 4,
              let isFromMeFlag = Int(parts[parts.count - 2])
        else {
            return nil
        }

        contactJid = String(parts[0])
        stanzaId = parts.dropFirst().dropLast(2).joined(separator: "_")
        isFromMe = isFromMeFlag == 1
    }

}
