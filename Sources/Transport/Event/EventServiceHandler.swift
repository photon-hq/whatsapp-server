import Application
import GRPCCore

struct EventServiceHandler: PWApp_EventService.ServiceProtocol {

    let events: EventService

    func catchUpEvents(
        request: ServerRequest<PWApp_CatchUpEventsRequest>,
        context: ServerContext
    ) async throws -> StreamingServerResponse<PWApp_CatchUpEventsResponse> {
        let replay = try await events.catchUpEvents(
            afterSequence: request.message.hasAfterSequence
                ? request.message.afterSequence
                : nil
        )

        return StreamingHeartbeat.finiteResponse(
            from: replay.events,
            mapEvent: EventStreamMapper.toProto
        ) {
            var response = PWApp_CatchUpEventsResponse()
            response.payload = .heartbeat(PWApp_Heartbeat())

            return response
        } makeComplete: {
            EventStreamMapper.toProtoComplete(headSequence: replay.headSequence)
        }
    }

}
