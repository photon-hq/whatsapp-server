package struct PollCreationReadbackQuery: Sendable, Equatable {

    package let pollId: String
    package let recipient: String

    package init(
        pollId: String,
        recipient: String
    ) {
        self.pollId = pollId
        self.recipient = recipient
    }

}

package struct PollUpdateReadbackQuery: Sendable, Equatable {

    package let pollId: String
    package let previousDigest: String?

    package init(
        pollId: String,
        previousDigest: String? = nil
    ) {
        self.pollId = pollId
        self.previousDigest = previousDigest
    }

}

package struct PollMutationReadbackResult: Sendable, Equatable {

    package let poll: Poll
    package let digest: String?

    package var pollId: String {
        poll.pollId
    }

    package init(
        poll: Poll,
        digest: String? = nil
    ) {
        self.poll = poll
        self.digest = digest
    }

    package func isSamePoll(as otherPollId: String) -> Bool {
        PollIdentifier.samePoll(pollId, otherPollId)
    }

}
