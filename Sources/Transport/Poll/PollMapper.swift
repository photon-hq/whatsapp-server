import SwiftProtobuf
import Domain

enum PollMapper {

    static func toResponse(_ poll: Poll) throws -> PWApp_PollResponse {
        var response = PWApp_PollResponse()
        response.poll = try toProto(poll)
        return response
    }

    static func toProto(_ poll: Poll) throws -> PWApp_Poll {
        var proto = PWApp_Poll()
        proto.pollID = poll.pollId
        proto.question = poll.question
        proto.choices = try poll.choices.enumerated().map { index, option in
            try toProto(option, field: "choices[\(index)]")
        }
        proto.allowMultipleChoices = poll.allowMultipleChoices
        proto.hideVoterNames = poll.hideVoterNames

        return proto
    }

    private static func toProto(
        _ option: PollChoice,
        field: String
    ) throws -> PWApp_PollChoice {
        var proto = PWApp_PollChoice()
        proto.index = try protoInt32(option.index, field: "\(field).index")
        proto.text = option.text
        proto.voteCount = try protoInt32(option.voteCount, field: "\(field).vote_count")

        return proto
    }

    private static func protoInt32(_ value: Int, field: String) throws -> Int32 {
        guard value >= Int(Int32.min), value <= Int(Int32.max) else {
            throw DomainError(.internalError, "Domain value exceeds proto int32 range")
                .with("field", field)
                .with("value", value)
        }

        return Int32(value)
    }

}
