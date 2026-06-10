import Domain
import Foundation

package extension MessageService {

    func sendContact(
        recipient: String,
        contacts: [ContactCardPayload],
        clientMessageId: String? = nil
    ) async throws -> MessageSnapshot {
        let clientMessageId = try IdentifierInput.clientMessageId(clientMessageId)

        guard !contacts.isEmpty else {
            throw DomainError(.invalidArgument, "contacts is required")
                .with("field", "contacts")
        }

        for (index, contact) in contacts.enumerated() {
            let hasName = contact.name?.isEmpty == false
            let hasVcard = contact.vcard?.isEmpty == false
            guard hasName || hasVcard else {
                throw DomainError(.invalidArgument, "contact requires a name or a vcard")
                    .with("field", "contacts[\(index)]")
            }

            guard hasVcard
                || !contact.phones.isEmpty
                || !contact.emails.isEmpty
                || contact.organization?.isEmpty == false
            else {
                throw DomainError(
                    .invalidArgument,
                    "contact requires a vcard or at least one phone/email/organization field"
                )
                .with("field", "contacts[\(index)]")
            }
        }

        let command = SendContactCommand(
            recipient: try RecipientInput.phone(recipient),
            contacts: contacts
        )
        // Consecutive contact sends are otherwise indistinguishable in
        // ChatStorage (no helper-side identifier), so the persisted vCard
        // display name is used as a discriminator.
        let expectedVcardName = contacts.first.flatMap { contact in
            contact.name?.isEmpty == false
                ? contact.name
                : contact.vcard.flatMap(Self.vcardDisplayName)
        }
        let startedAt = Date()

        return try await mutationPolicy.execute(
            clientMessageId: clientMessageId
        ) {
            try await sendContact.sendContact(command)

            guard let readback = try await ReadbackRetry.search(
                delaysNs: mutationReadbackDelaysNs,
                attempt: {
                    try await mutationReadback.sentAttachment(
                        matching: SentAttachmentReadbackQuery(
                            recipient: command.recipient,
                            kind: .contact,
                            vcardName: expectedVcardName,
                            notBefore: startedAt
                        )
                    )
                }
            ) else {
                throw DomainError(.timeout, "Sent contact did not become visible in ChatStorage in time")
                    .with("recipient", command.recipient)
            }

            return readback
        }
    }

    private static func vcardDisplayName(_ vcard: String) -> String? {
        for rawLine in vcard.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.uppercased().hasPrefix("FN") else {
                continue
            }

            guard let colon = line.firstIndex(of: ":") else {
                continue
            }

            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }

        return nil
    }

}
