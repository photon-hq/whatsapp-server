package struct PollChoice: Codable, Sendable, Equatable {

    package let index: Int
    package let text: String
    package let voteCount: Int

    package init(
        index: Int,
        text: String,
        voteCount: Int
    ) {
        self.index = index
        self.text = text
        self.voteCount = voteCount
    }

}
