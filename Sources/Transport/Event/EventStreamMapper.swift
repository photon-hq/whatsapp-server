import Domain

enum EventStreamMapper {

    static func toProto(
        _ event: CaughtUpDomainEvent
    ) throws -> PWApp_CatchUpEventsResponse {
        var response = PWApp_CatchUpEventsResponse()

        switch event {
        case .message(let change):
            response.sequence = change.sequence
            response.payload = .messageChanged(MessageStreamMapper.toProto(change))

        case .poll(let change):
            response.sequence = change.sequence
            response.payload = .pollChanged(try PollStreamMapper.toProto(change.change))
        }

        return response
    }

    static func toProtoComplete(
        headSequence: UInt64
    ) -> PWApp_CatchUpEventsResponse {
        var response = PWApp_CatchUpEventsResponse()
        var payload = PWApp_CatchUpEventsComplete()
        payload.headSequence = headSequence
        response.payload = .complete(payload)

        return response
    }

}
