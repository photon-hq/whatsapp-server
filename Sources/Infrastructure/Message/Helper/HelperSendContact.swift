import Domain
import Foundation

package struct HelperSendContact: SendContact, Sendable {

    let client: any HelperCommandTransport

    package init(client: any HelperCommandTransport) {
        self.client = client
    }

    package func sendContact(
        _ command: SendContactCommand
    ) async throws {
        let contacts = command.contacts.map { contact -> JSONValue in
            var entry: [String: JSONValue] = [:]

            if let name = contact.name {
                entry["name"] = .string(name)
            }

            if let vcard = contact.vcard {
                entry["vcard"] = .string(vcard)
            }

            if !contact.phones.isEmpty {
                entry["phones"] = .array(contact.phones.map(JSONValue.string))
            }

            if !contact.emails.isEmpty {
                entry["emails"] = .array(contact.emails.map(JSONValue.string))
            }

            if let organization = contact.organization {
                entry["org"] = .string(organization)
            }

            return .object(entry)
        }

        let data: [String: JSONValue] = [
            "phone": .string(command.recipient),
            "contacts": .array(contacts)
        ]

        let response = try await client.sendCommand(action: "send-contact", data: data)
        try HelperJSON.requireAccepted(response)
    }

}
