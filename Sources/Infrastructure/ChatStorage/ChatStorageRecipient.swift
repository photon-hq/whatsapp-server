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

    private var partnerPhone: String? {
        guard let phone = partnerName?.filter(\.isNumber),
              !phone.isEmpty
        else {
            return nil
        }

        return phone
    }

}
