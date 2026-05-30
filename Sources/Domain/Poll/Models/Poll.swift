package struct Poll: Codable, Sendable, Equatable {

    package let pollId: String
    package let question: String
    package let choices: [PollChoice]
    package let allowMultipleChoices: Bool
    package let hideVoterNames: Bool

    package init(
        pollId: String,
        question: String,
        choices: [PollChoice],
        allowMultipleChoices: Bool,
        hideVoterNames: Bool
    ) {
        self.pollId = pollId
        self.question = question
        self.choices = choices
        self.allowMultipleChoices = allowMultipleChoices
        self.hideVoterNames = hideVoterNames
    }

}
