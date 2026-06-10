struct ChatStorageRecipient {

    let contactJid: String
    let partnerName: String?

    var publicValue: String {
        if contactJid.hasSuffix("@s.whatsapp.net") {
            return String(contactJid.dropLast("@s.whatsapp.net".count))
        }

        if contactJid.hasSuffix("@g.us") {
            return contactJid
        }

        if let phone = partnerPhone {
            return phone
        }

        return contactJid
    }

    func matches(_ recipient: String) -> Bool {
        publicValue == recipient
            || contactJid.contains(recipient)
            || partnerPhone == recipient
    }

    /// Modern WhatsApp stores most 1:1 contacts under an opaque `@lid` session
    /// whose phone number is not recoverable from ChatStorage. When the contact
    /// is `@lid`-addressed and its partner name carries no phone digits, a phone
    /// `recipient` can never be matched, so callers must not treat a failed
    /// recipient match as proof the row belongs to a different chat.
    var canMatchByPhone: Bool {
        if contactJid.hasSuffix("@s.whatsapp.net") || contactJid.hasSuffix("@g.us") {
            return true
        }

        return partnerPhone != nil
    }

    private var partnerPhone: String? {
        guard let phone = partnerName?.filter(\.isNumber),
              !phone.isEmpty
        else {
            return nil
        }

        return phone
    }

}
