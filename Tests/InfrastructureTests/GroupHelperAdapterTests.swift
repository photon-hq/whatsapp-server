import Foundation
import XCTest
@testable import Domain
@testable import Infrastructure

final class GroupHelperAdapterTests: XCTestCase {

    func testCreateGroupMapsFullPayload() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "groupJID": .string("120363000000000000@g.us"),
            "updated": .object(["avatar": .bool(true)])
        ])
        let adapter = HelperCreateGroup(client: transport)

        let avatar: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        let result = try await adapter.createGroup(
            CreateGroupCommand(
                subject: "Project Team",
                participants: ["8613800138000", "8613800138001"],
                description: "Internal",
                avatar: avatar,
                disappearingDuration: 604_800,
                permissions: GroupPermissions(
                    restrictEditInfo: true,
                    restrictSendMessages: true,
                    restrictAddMembers: false,
                    restrictInviteLink: true,
                    requireMemberApproval: false
                ),
                tempGuid: "temp-1"
            )
        )

        let action = await transport.lastAction
        XCTAssertEqual(action, "create-group")

        let data = await transport.lastData
        XCTAssertEqual(data?["subject"]?.stringValue, "Project Team")
        XCTAssertEqual(
            data?["participants"]?.arrayValue?.compactMap { $0.stringValue },
            ["8613800138000", "8613800138001"]
        )
        XCTAssertEqual(data?["description"]?.stringValue, "Internal")
        XCTAssertEqual(data?["disappearingDuration"]?.intValue, 604_800)
        XCTAssertEqual(data?["restrictEditInfo"]?.boolValue, true)
        XCTAssertEqual(data?["restrictSendMessages"]?.boolValue, true)
        XCTAssertEqual(data?["restrictAddMembers"]?.boolValue, false)
        XCTAssertEqual(data?["restrictInviteLink"]?.boolValue, true)
        XCTAssertEqual(data?["requireMemberApproval"]?.boolValue, false)
        XCTAssertEqual(data?["tempGuid"]?.stringValue, "temp-1")
        XCTAssertEqual(
            data?["avatarData"]?.stringValue,
            Data(avatar).base64EncodedString()
        )

        XCTAssertEqual(result.groupJID, "120363000000000000@g.us")
        XCTAssertTrue(result.accepted)
        XCTAssertTrue(result.avatarUpdated)
    }

    func testCreateGroupOmitsOptionalFields() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "identifier": .string("120363@g.us")
        ])
        let adapter = HelperCreateGroup(client: transport)

        let result = try await adapter.createGroup(
            CreateGroupCommand(
                subject: "Team",
                participants: ["8613800138000"]
            )
        )

        let data = await transport.lastData
        XCTAssertNil(data?["description"])
        XCTAssertNil(data?["avatarData"])
        XCTAssertNil(data?["tempGuid"])
        XCTAssertEqual(data?["disappearingDuration"]?.intValue, 0)

        XCTAssertEqual(result.groupJID, "120363@g.us")
        XCTAssertFalse(result.avatarUpdated)
    }

    func testCreateGroupSurfacesAvatarNotAppliedFromHelper() async throws {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true),
            "groupJID": .string("120363@g.us"),
            "updated": .object(["avatar": .bool(false)])
        ])
        let adapter = HelperCreateGroup(client: transport)

        let result = try await adapter.createGroup(
            CreateGroupCommand(
                subject: "Team",
                participants: ["8613800138000"],
                avatar: [0x89, 0x50]
            )
        )

        XCTAssertFalse(result.avatarUpdated)
    }

    func testCreateGroupRejectsHelperReject() async {
        let transport = RecordingTransport(response: [
            "accepted": .bool(false)
        ])
        let adapter = HelperCreateGroup(client: transport)

        do {
            _ = try await adapter.createGroup(
                CreateGroupCommand(subject: "Team", participants: ["8613800138000"])
            )
            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .internalError)
            XCTAssertEqual(error.context["field"], "accepted")
        } catch {
            XCTFail("Expected DomainError, got \(error)")
        }
    }

    func testCreateGroupRejectsMissingGroupJID() async {
        let transport = RecordingTransport(response: [
            "accepted": .bool(true)
        ])
        let adapter = HelperCreateGroup(client: transport)

        do {
            _ = try await adapter.createGroup(
                CreateGroupCommand(subject: "Team", participants: ["8613800138000"])
            )
            XCTFail("Expected DomainError")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .internalError)
            XCTAssertEqual(error.context["field"], "groupJID")
        } catch {
            XCTFail("Expected DomainError, got \(error)")
        }
    }

}
