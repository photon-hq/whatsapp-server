import Domain
import Foundation
import GRDB

struct ChatStorageEventRecord: Decodable, FetchableRecord, Sendable {

    let rowId: Int64
    let contactJid: String
    let partnerName: String?
    let stanzaId: String
    let text: String?
    let isFromMe: Bool
    let messageType: Int
    let messageDate: Double?
    let parentContactJid: String?
    let parentStanzaId: String?
    let parentIsFromMe: Bool?
    let mediaLocalPath: String?
    let mediaFileSize: Int64?
    let mediaTitle: String?
    let mediaVCardName: String?
    let mediaLatitude: Double?
    let mediaLongitude: Double?
    let mediaMetadata: Data?
    let receiptInfo: Data?

    enum CodingKeys: String, CodingKey {
        case rowId
        case contactJid
        case partnerName
        case stanzaId
        case text
        case isFromMe
        case messageType
        case messageDate
        case parentContactJid
        case parentStanzaId
        case parentIsFromMe
        case mediaLocalPath
        case mediaFileSize
        case mediaTitle
        case mediaVCardName
        case mediaLatitude
        case mediaLongitude
        case mediaMetadata
        case receiptInfo
    }

    var uniqueKey: String {
        "\(contactJid)_\(stanzaId)_\(isFromMe ? 1 : 0)_0"
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

    var messageText: MessageText? {
        guard !isPollMessage else {
            return nil
        }

        guard !hasAttachmentMetadata else {
            return nil
        }

        guard let text, !text.isEmpty else {
            return nil
        }

        return MessageText(
            messageId: uniqueKey,
            text: text,
            replyToMessageId: replyToMessageId
        )
    }

    var attachment: MessageAttachment? {
        guard !isPollMessage else {
            return nil
        }

        guard hasAttachmentMetadata else {
            return nil
        }

        return MessageAttachment(
            messageId: uniqueKey,
            kind: attachmentKind,
            caption: attachmentCaption,
            localPath: mediaLocalPath,
            fileSize: mediaFileSize.map { $0 > 0 ? $0 : nil } ?? nil,
            title: attachmentTitle,
            replyToMessageId: replyToMessageId
        )
    }

    private var attachmentCaption: String? {
        if let text, !text.isEmpty {
            return text
        }

        if isVisualMedia,
           let mediaTitle,
           !mediaTitle.isEmpty {
            return mediaTitle
        }

        return nil
    }

    private var attachmentTitle: String? {
        if messageType == 4,
           mediaLocalPath?.isEmpty != false,
           mediaVCardName?.isEmpty == false {
            return mediaVCardName
        }

        if isVisualMedia {
            return nil
        }

        return mediaTitle?.isEmpty == false ? mediaTitle : nil
    }

    private var hasAttachmentMetadata: Bool {
        mediaLocalPath?.isEmpty == false
            || mediaTitle?.isEmpty == false
            || mediaVCardName?.isEmpty == false
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

            return .document
        }

        if mediaVCardName?.isEmpty == false {
            return .contact
        }

        if hasLocationMetadata {
            return .location
        }

        return .document
    }

    private var isVisualMedia: Bool {
        attachmentKind == .image || attachmentKind == .video
    }

    private var hasLocationMetadata: Bool {
        guard let latitude = mediaLatitude,
              let longitude = mediaLongitude
        else {
            return false
        }

        return latitude != 0 || longitude != 0
    }

    var isPollMessage: Bool {
        messageType == 46
            || (messageType == 13 && poll != nil)
    }

    var poll: Poll? {
        guard messageType == 13 || messageType == 46
        else {
            return nil
        }

        return WhatsAppPollSnapshotParser.parse(
            pollId: uniqueKey,
            metadata: mediaMetadata,
            receiptInfo: receiptInfo
        )
    }

    var occurredAt: Date {
        WhatsAppDate.fromStoredSeconds(messageDate) ?? Date()
    }

}
