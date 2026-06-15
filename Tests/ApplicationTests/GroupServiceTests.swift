import XCTest
@testable import Application
@testable import Domain

final class GroupServiceTests: XCTestCase {

    func testTrimsSubjectAndForwardsCommand() async throws {
        let recorder = GroupCommandRecorder()
        let service = GroupService(createGroup: recorder)

        let result = try await service.createGroup(
            subject: "  Project Team  ",
            participants: ["8613800138000", " 8613800138001 "],
            description: "  Internal  ",
            avatar: [0x89, 0x50],
            disappearingDuration: 604_800,
            permissions: GroupPermissions(restrictSendMessages: true),
            tempGuid: "temp-1"
        )

        let command = await recorder.lastCommand
        XCTAssertEqual(command?.subject, "Project Team")
        XCTAssertEqual(command?.participants, ["8613800138000", "8613800138001"])
        XCTAssertEqual(command?.description, "Internal")
        XCTAssertEqual(command?.disappearingDuration, 604_800)
        XCTAssertEqual(command?.permissions.restrictSendMessages, true)
        XCTAssertEqual(command?.tempGuid, "temp-1")
        XCTAssertEqual(result.groupJID, "120363@g.us")
        XCTAssertTrue(result.avatarUpdated)
    }

    func testDropsBlankDescription() async throws {
        let recorder = GroupCommandRecorder()
        let service = GroupService(createGroup: recorder)

        _ = try await service.createGroup(
            subject: "Team",
            participants: ["8613800138000"],
            description: "   ",
            avatar: nil,
            disappearingDuration: 0,
            permissions: GroupPermissions(),
            tempGuid: nil
        )

        let command = await recorder.lastCommand
        XCTAssertNil(command?.description)
    }

    func testRejectsEmptySubject() async {
        await assertInvalidArgument(field: "subject") { service in
            _ = try await service.createGroup(
                subject: "   ",
                participants: ["8613800138000"],
                description: nil,
                avatar: nil,
                disappearingDuration: 0,
                permissions: GroupPermissions(),
                tempGuid: nil
            )
        }
    }

    func testRejectsEmptyParticipants() async {
        await assertInvalidArgument(field: "participants") { service in
            _ = try await service.createGroup(
                subject: "Team",
                participants: [],
                description: nil,
                avatar: nil,
                disappearingDuration: 0,
                permissions: GroupPermissions(),
                tempGuid: nil
            )
        }
    }

    func testRejectsNonNumericParticipant() async {
        await assertInvalidArgument(field: "participants[1]") { service in
            _ = try await service.createGroup(
                subject: "Team",
                participants: ["8613800138000", "+8613800138001"],
                description: nil,
                avatar: nil,
                disappearingDuration: 0,
                permissions: GroupPermissions(),
                tempGuid: nil
            )
        }
    }

    func testRejectsInvalidDisappearingDuration() async {
        await assertInvalidArgument(field: "disappearingDuration") { service in
            _ = try await service.createGroup(
                subject: "Team",
                participants: ["8613800138000"],
                description: nil,
                avatar: nil,
                disappearingDuration: 12_345,
                permissions: GroupPermissions(),
                tempGuid: nil
            )
        }
    }

    func testRejectsEmptyAvatar() async {
        await assertInvalidArgument(field: "avatar") { service in
            _ = try await service.createGroup(
                subject: "Team",
                participants: ["8613800138000"],
                description: nil,
                avatar: [],
                disappearingDuration: 0,
                permissions: GroupPermissions(),
                tempGuid: nil
            )
        }
    }

    private func assertInvalidArgument(
        field: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: (GroupService) async throws -> Void
    ) async {
        let service = GroupService(createGroup: GroupCommandRecorder())

        do {
            try await operation(service)
            XCTFail("expected invalidArgument", file: file, line: line)
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .invalidArgument, file: file, line: line)
            XCTAssertEqual(error.context["field"], field, file: file, line: line)
        } catch {
            XCTFail("unexpected error: \(error)", file: file, line: line)
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
