import XCTest
@testable import Application
@testable import Domain

private actor PollCommandRecorder:
    CreatePoll,
    VotePoll,
    UnvotePoll,
    GetPoll,
    PollMutationReadback
{

    private(set) var lastCreateCommand: CreatePollCommand?
    private(set) var lastVoteCommand: VotePollCommand?
    private(set) var lastUnvotePollId: String?
    private(set) var createCount = 0
    private(set) var voteCount = 0
    private(set) var unvoteCount = 0
    private(set) var getCount = 0
    var getPollError: (any Error)?
    var readbackError: (any Error)?
    var pollOptionVoteCount = 0
    var pollDigest = "created"

    func createPoll(_ command: CreatePollCommand) async throws -> String {
        lastCreateCommand = command
        createCount += 1
        pollOptionVoteCount = 0
        pollDigest = "created"
        return "poll-1"
    }

    func votePoll(_ command: VotePollCommand) async throws {
        lastVoteCommand = command
        voteCount += 1
        pollOptionVoteCount = 1
        pollDigest = "voted-\(voteCount)"
    }

    func unvotePoll(pollId: String) async throws {
        lastUnvotePollId = pollId
        unvoteCount += 1
        pollOptionVoteCount = 0
        pollDigest = "unvoted-\(unvoteCount)"
    }

    func getPoll(pollId: String) async throws -> Poll {
        if let getPollError {
            throw getPollError
        }

        getCount += 1

        return poll(pollId: pollId)
    }

    private func poll(pollId: String) -> Poll {
        Poll(
            pollId: pollId,
            question: "Lunch?",
            choices: [
                PollChoice(index: 0, text: "Sushi", voteCount: pollOptionVoteCount),
                PollChoice(index: 1, text: "Pizza", voteCount: 0)
            ],
            allowMultipleChoices: true,
            hideVoterNames: false
        )
    }

    func createdPoll(
        matching query: PollCreationReadbackQuery
    ) async throws -> PollMutationReadbackResult? {
        if let readbackError {
            throw readbackError
        }

        return PollMutationReadbackResult(poll: poll(pollId: query.pollId), digest: pollDigest)
    }

    func currentPollUpdate(
        pollId: String
    ) async throws -> PollMutationReadbackResult? {
        if let readbackError {
            throw readbackError
        }

        return PollMutationReadbackResult(poll: poll(pollId: pollId), digest: pollDigest)
    }

    func updatedPoll(
        matching query: PollUpdateReadbackQuery
    ) async throws -> PollMutationReadbackResult? {
        if let readbackError {
            throw readbackError
        }

        guard pollDigest != query.previousDigest else {
            return nil
        }

        return PollMutationReadbackResult(poll: poll(pollId: query.pollId), digest: pollDigest)
    }

}

final class PollServiceTests: XCTestCase {

    func testCreatePollNormalizesChoices() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        let poll = try await service.createPoll(
            recipient: "11234567890",
            question: "Lunch?",
            choices: [" Sushi ", "Pizza "],
            allowMultipleChoices: true
        )

        XCTAssertEqual(poll.pollId, "poll-1")
        XCTAssertEqual(poll.question, "Lunch?")

        let command = await recorder.lastCreateCommand
        XCTAssertEqual(command?.choices, ["Sushi", "Pizza"])
        XCTAssertEqual(command?.allowMultipleChoices, true)

        let getCount = await recorder.getCount
        XCTAssertEqual(getCount, 0)
    }

    func testCreatePollRejectsDuplicateClientMessageId() async throws {
        let recorder = PollCommandRecorder()
        let checker = TestDeduplicationChecker()
        let service = pollService(recorder, checker: checker)

        let poll = try await service.createPoll(
            recipient: "11234567890",
            question: "Lunch?",
            choices: ["Sushi", "Pizza"],
            clientMessageId: "cmid-1"
        )

        XCTAssertEqual(poll.pollId, "poll-1")

        await XCTAssertThrowsErrorAsync {
            _ = try await service.createPoll(
                recipient: "11234567890",
                question: "Lunch?",
                choices: ["Sushi", "Pizza"],
                clientMessageId: "cmid-1"
            )
        }

        let createCount = await recorder.createCount
        XCTAssertEqual(createCount, 1)

        let getCount = await recorder.getCount
        XCTAssertEqual(getCount, 0)
    }

    func testCreatePollRejectsBlankClientMessageId() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.createPoll(
                recipient: "11234567890",
                question: "Lunch?",
                choices: ["Sushi", "Pizza"],
                clientMessageId: "   "
            )
        }

        let createCount = await recorder.createCount
        XCTAssertEqual(createCount, 0)
    }

    func testCreatePollReleasesDeduplicationAfterReadbackFailure() async throws {
        let recorder = PollCommandRecorder()
        await recorder.setReadbackError(DomainError(.serviceUnavailable, "readback failed"))

        let checker = TestDeduplicationChecker()
        let service = pollService(recorder, checker: checker)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.createPoll(
                recipient: "11234567890",
                question: "Lunch?",
                choices: ["Sushi", "Pizza"],
                clientMessageId: "cmid-1"
            )
        }

        await recorder.setReadbackError(nil)

        _ = try await service.createPoll(
            recipient: "11234567890",
            question: "Lunch?",
            choices: ["Sushi", "Pizza"],
            clientMessageId: "cmid-1"
        )

        let createCount = await recorder.createCount
        XCTAssertEqual(createCount, 2)
    }

    func testVotePollRejectsDuplicateIndexes() async {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.votePoll(pollId: "poll-1", choiceIndexes: [0, 0])
        }
    }

    func testVotePollReturnsPollAfterReadback() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        let poll = try await service.votePoll(
            pollId: "poll-1",
            choiceIndexes: [0]
        )

        XCTAssertEqual(poll.pollId, "poll-1")
        XCTAssertEqual(poll.question, "Lunch?")

        let command = await recorder.lastVoteCommand
        XCTAssertEqual(command?.pollId, "poll-1")
        XCTAssertEqual(command?.choiceIndexes, [0])

        let getCount = await recorder.getCount
        XCTAssertEqual(getCount, 0)
    }

    func testVotePollRejectsDuplicateClientMessageId() async throws {
        let recorder = PollCommandRecorder()
        let checker = TestDeduplicationChecker()
        let service = pollService(recorder, checker: checker)

        _ = try await service.votePoll(
            pollId: "poll-1",
            choiceIndexes: [0],
            clientMessageId: "vote-1"
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await service.votePoll(
                pollId: "poll-1",
                choiceIndexes: [0],
                clientMessageId: "vote-1"
            )
        }

        let voteCount = await recorder.voteCount
        XCTAssertEqual(voteCount, 1)
    }

    func testVotePollRejectsBlankClientMessageId() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.votePoll(
                pollId: "poll-1",
                choiceIndexes: [0],
                clientMessageId: "   "
            )
        }

        let voteCount = await recorder.voteCount
        XCTAssertEqual(voteCount, 0)
    }

    func testUnvotePollReturnsPollAfterReadback() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        let poll = try await service.unvotePoll(pollId: "poll-1")

        XCTAssertEqual(poll.pollId, "poll-1")

        let pollId = await recorder.lastUnvotePollId
        XCTAssertEqual(pollId, "poll-1")

        let getCount = await recorder.getCount
        XCTAssertEqual(getCount, 0)
    }

    func testUnvotePollRejectsDuplicateClientMessageId() async throws {
        let recorder = PollCommandRecorder()
        let checker = TestDeduplicationChecker()
        let service = pollService(recorder, checker: checker)

        _ = try await service.unvotePoll(
            pollId: "poll-1",
            clientMessageId: "unvote-1"
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await service.unvotePoll(
                pollId: "poll-1",
                clientMessageId: "unvote-1"
            )
        }

        let unvoteCount = await recorder.unvoteCount
        XCTAssertEqual(unvoteCount, 1)
    }

    func testUnvotePollRejectsBlankClientMessageId() async throws {
        let recorder = PollCommandRecorder()
        let service = pollService(recorder)

        await XCTAssertThrowsErrorAsync {
            _ = try await service.unvotePoll(
                pollId: "poll-1",
                clientMessageId: "   "
            )
        }

        let unvoteCount = await recorder.unvoteCount
        XCTAssertEqual(unvoteCount, 0)
    }

}

private func pollService(
    _ recorder: PollCommandRecorder,
    checker: (any DeduplicationChecking)? = nil
) -> PollService {
    PollService(
        createPoll: recorder,
        votePoll: recorder,
        unvotePoll: recorder,
        getPoll: recorder,
        mutationReadback: recorder,
        mutationPolicy: applicationTestMutationPolicy(checker: checker),
        eventStreaming: TestEventStream(),
        mutationReadbackDelaysNs: [0]
    )
}

extension PollCommandRecorder {

    func setGetPollError(_ error: (any Error)?) {
        getPollError = error
    }

    func setReadbackError(_ error: (any Error)?) {
        readbackError = error
    }

}
