import Application
import GRPCCore

struct PollServiceHandler: PWApp_PollService.ServiceProtocol {

    let polls: PollService

    func createPoll(
        request: ServerRequest<PWApp_CreatePollRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_PollResponse> {
        let message = request.message

        let poll = try await polls.createPoll(
            recipient: message.recipient,
            question: message.question,
            choices: message.choices,
            allowMultipleChoices: message.allowMultipleChoices,
            hideVoterNames: message.hideVoterNames,
            closesAt: message.hasClosesAt ? message.closesAt.date : nil,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: try PollMapper.toResponse(poll))
    }

    func votePoll(
        request: ServerRequest<PWApp_VotePollRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_PollResponse> {
        let message = request.message

        let poll = try await polls.votePoll(
            pollId: message.pollID,
            choiceIndexes: message.choiceIndexes.map(Int.init),
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: try PollMapper.toResponse(poll))
    }

    func unvotePoll(
        request: ServerRequest<PWApp_UnvotePollRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_PollResponse> {
        let message = request.message

        let poll = try await polls.unvotePoll(
            pollId: message.pollID,
            clientMessageId: message.hasClientMessageID ? message.clientMessageID : nil
        )

        return ServerResponse(message: try PollMapper.toResponse(poll))
    }

    func getPoll(
        request: ServerRequest<PWApp_GetPollRequest>,
        context: ServerContext
    ) async throws -> ServerResponse<PWApp_PollResponse> {
        let message = request.message

        let poll = try await polls.getPoll(pollId: message.pollID)

        return ServerResponse(message: try PollMapper.toResponse(poll))
    }

    func subscribePollEvents(
        request: ServerRequest<PWApp_SubscribePollEventsRequest>,
        context: ServerContext
    ) async throws -> StreamingServerResponse<PWApp_SubscribePollEventsResponse> {
        let message = request.message

        let stream = try await polls.subscribeEvents(
            pollId: message.hasPollID ? message.pollID : nil
        )

        return StreamingHeartbeat.response(
            from: stream,
            mapEvent: PollStreamMapper.toProto
        ) {
            var response = PWApp_SubscribePollEventsResponse()
            response.payload = .heartbeat(PWApp_Heartbeat())

            return response
        }
    }

}
