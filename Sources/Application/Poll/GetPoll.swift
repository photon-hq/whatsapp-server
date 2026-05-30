import Domain

package extension PollService {

    func getPoll(pollId: String) async throws -> Poll {
        let pollId = try IdentifierInput.required(pollId, field: "poll_id")

        return try await getPoll.getPoll(pollId: pollId)
    }

}
