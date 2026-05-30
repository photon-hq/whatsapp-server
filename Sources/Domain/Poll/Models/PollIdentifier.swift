package enum PollIdentifier {

    package static func stanzaId(from pollId: String) -> String? {
        let parts = pollId.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count >= 4 else { return nil }

        return parts.dropFirst().dropLast(2).joined(separator: "_")
    }

    package static func samePoll(_ pollId: String, _ otherPollId: String) -> Bool {
        guard pollId != otherPollId else { return true }
        guard let stanzaId = Self.stanzaId(from: pollId),
              let otherStanzaId = Self.stanzaId(from: otherPollId)
        else {
            return false
        }

        return stanzaId == otherStanzaId
    }

}
