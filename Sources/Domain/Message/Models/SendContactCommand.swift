package struct ContactCardPayload: Sendable, Equatable {

    package let name: String?
    package let vcard: String?
    package let phones: [String]
    package let emails: [String]
    package let organization: String?

    package init(
        name: String? = nil,
        vcard: String? = nil,
        phones: [String] = [],
        emails: [String] = [],
        organization: String? = nil
    ) {
        self.name = name
        self.vcard = vcard
        self.phones = phones
        self.emails = emails
        self.organization = organization
    }

}

package struct SendContactCommand: Sendable, Equatable {

    package let recipient: String
    package let contacts: [ContactCardPayload]

    package init(
        recipient: String,
        contacts: [ContactCardPayload]
    ) {
        self.recipient = recipient
        self.contacts = contacts
    }

}
