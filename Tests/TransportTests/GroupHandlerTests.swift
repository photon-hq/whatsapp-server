import GRPCCore
import GRPCInProcessTransport
import XCTest
@testable import Application
@testable import Domain
@testable import Transport

final class GroupHandlerTests: XCTestCase {

    func testCreateGroupGoesThroughGeneratedGrpcContract() async throws {
        let recorder = GroupCommandRecorder()
        let service = GroupService(createGroup: recorder)

        try await withGroupClient(service: service) { client in
            var request = PWApp_CreateGroupRequest()
            request.subject = "Project Team"
            request.participants = ["8613800138000", "8613800138001"]
            request.groupDescription = "Internal"
            request.disappearingDuration = 604_800
            request.restrictSendMessages = true
            request.requireMemberApproval = true
            request.tempGuid = "temp-1"

            let response = try await client.createGroup(request)

            XCTAssertEqual(response.groupJid, "120363@g.us")
            XCTAssertTrue(response.accepted)
        }

        let command = await recorder.lastCommand
        XCTAssertEqual(command?.subject, "Project Team")
        XCTAssertEqual(command?.participants, ["8613800138000", "8613800138001"])
        XCTAssertEqual(command?.description, "Internal")
        XCTAssertEqual(command?.disappearingDuration, 604_800)
        XCTAssertEqual(command?.permissions.restrictSendMessages, true)
        XCTAssertEqual(command?.permissions.requireMemberApproval, true)
        XCTAssertEqual(command?.tempGuid, "temp-1")
    }

    func testCreateGroupMapsAvatarUpdated() async throws {
        let recorder = GroupCommandRecorder()
        let service = GroupService(createGroup: recorder)

        try await withGroupClient(service: service) { client in
            var request = PWApp_CreateGroupRequest()
            request.subject = "Team"
            request.participants = ["8613800138000"]
            request.avatar = Data([0x89, 0x50, 0x4E, 0x47])

            let response = try await client.createGroup(request)

            XCTAssertTrue(response.avatarUpdated)
        }
    }

    func testCreateGroupRejectsEmptySubject() async throws {
        let recorder = GroupCommandRecorder()
        let service = GroupService(createGroup: recorder)

        try await withGroupClient(service: service) { client in
            await assertRPCInvalidArgument(field: "subject") {
                var request = PWApp_CreateGroupRequest()
                request.subject = "   "
                request.participants = ["8613800138000"]
                _ = try await client.createGroup(request)
            }
        }
    }

    func testCreateGroupRejectsEmptyParticipants() async throws {
        let recorder = GroupCommandRecorder()
        let service = GroupService(createGroup: recorder)

        try await withGroupClient(service: service) { client in
            await assertRPCInvalidArgument(field: "participants") {
                var request = PWApp_CreateGroupRequest()
                request.subject = "Team"
                _ = try await client.createGroup(request)
            }
        }
    }

    private func withGroupClient(
        service: GroupService,
        _ body: (PWApp_GroupService.Client<InProcessTransport.Client>) async throws -> Void
    ) async throws {
        let inProcess = InProcessTransport()
        try await withGRPCServer(
            transport: inProcess.server,
            services: [GroupServiceHandler(group: service)]
        ) { _ in
            try await withGRPCClient(transport: inProcess.client) { client in
                try await body(PWApp_GroupService.Client(wrapping: client))
            }
        }
    }

    private func assertRPCInvalidArgument(
        field: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected invalidArgument", file: file, line: line)
        } catch let error as RPCError {
            XCTAssertEqual(error.code, .invalidArgument, file: file, line: line)
            XCTAssertEqual(
                Array(error.metadata[stringValues: "error-context-field"]).first,
                field,
                file: file,
                line: line
            )
        } catch {
            XCTFail("Expected RPCError, got \(error)", file: file, line: line)
        }
    }

}

private actor GroupCommandRecorder: CreateGroup {

    private(set) var lastCommand: CreateGroupCommand?

    func createGroup(_ command: CreateGroupCommand) async throws -> GroupCreationResult {
        lastCommand = command

        return GroupCreationResult(
            groupJID: "120363@g.us",
            accepted: true,
            avatarUpdated: command.avatar != nil
        )
    }

}
