import Domain
import SwiftProtobuf

enum PollStreamMapper {

    static func toProto(
        _ event: SequencedPollChange
    ) throws -> PWApp_SubscribePollEventsResponse {
        var response = PWApp_SubscribePollEventsResponse()
        response.sequence = event.sequence
        response.payload = .pollChanged(try toProto(event.change))

        return response
    }

    static func toProto(
        _ event: PollChangeEvent
    ) throws -> PWApp_PollChangeEvent {
        var proto = PWApp_PollChangeEvent()
        proto.recipient = event.recipient
        proto.pollID = event.pollId
        proto.occurredAt = Google_Protobuf_Timestamp(date: event.occurredAt)
        proto.isFromMe = event.isFromMe

        switch event.change {
        case .created(let poll):
            proto.change = .created(try PollMapper.toProto(poll))

        case .updated(let poll):
            proto.change = .updated(try PollMapper.toProto(poll))

        case .voteChanged(let poll):
            proto.change = .voteChanged(try PollMapper.toProto(poll))

        case .choicesChanged(let poll):
            proto.change = .choicesChanged(try PollMapper.toProto(poll))
        }

        return proto
    }

}
