package struct VotePollCommand: Sendable, Equatable {

    package let pollId: String
    package let choiceIndexes: [Int]

    package init(
        pollId: String,
        choiceIndexes: [Int]
    ) {
        self.pollId = pollId
        self.choiceIndexes = choiceIndexes
    }

}
