import Foundation

package struct CreatePollCommand: Sendable, Equatable {

    package let recipient: String
    package let question: String
    package let choices: [String]
    package let allowMultipleChoices: Bool
    package let hideVoterNames: Bool
    package let closesAt: Date?

    package init(
        recipient: String,
        question: String,
        choices: [String],
        allowMultipleChoices: Bool = false,
        hideVoterNames: Bool = false,
        closesAt: Date? = nil
    ) {
        self.recipient = recipient
        self.question = question
        self.choices = choices
        self.allowMultipleChoices = allowMultipleChoices
        self.hideVoterNames = hideVoterNames
        self.closesAt = closesAt
    }

}
