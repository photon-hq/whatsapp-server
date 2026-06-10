import XCTest
@testable import Application
@testable import Domain

final class ProfileServiceTests: XCTestCase {

    func testRejectsWhenNoFieldProvided() async {
        let recorder = ProfileCommandRecorder()
        let service = ProfileService(modifyProfile: recorder)

        do {
            _ = try await service.modifyProfile(name: nil, about: nil, avatar: nil)
            XCTFail("expected invalidArgument")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .invalidArgument)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testRejectsEmptyName() async {
        let recorder = ProfileCommandRecorder()
        let service = ProfileService(modifyProfile: recorder)

        do {
            _ = try await service.modifyProfile(name: "   ", about: nil, avatar: nil)
            XCTFail("expected invalidArgument")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .invalidArgument)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testTrimsNameAndForwardsCommand() async throws {
        let recorder = ProfileCommandRecorder()
        let service = ProfileService(modifyProfile: recorder)

        let result = try await service.modifyProfile(
            name: "  Alice  ",
            about: "Available",
            avatar: nil
        )

        let command = await recorder.lastCommand
        XCTAssertEqual(command?.name, "Alice")
        XCTAssertEqual(command?.about, "Available")
        XCTAssertNil(command?.avatar)
        XCTAssertTrue(result.nameUpdated)
        XCTAssertTrue(result.aboutUpdated)
        XCTAssertFalse(result.avatarUpdated)
    }

    func testAllowsEmptyAboutToClearStatus() async throws {
        let recorder = ProfileCommandRecorder()
        let service = ProfileService(modifyProfile: recorder)

        _ = try await service.modifyProfile(name: nil, about: "", avatar: nil)

        let command = await recorder.lastCommand
        XCTAssertEqual(command?.about, "")
    }

    func testRejectsEmptyAvatar() async {
        let recorder = ProfileCommandRecorder()
        let service = ProfileService(modifyProfile: recorder)

        do {
            _ = try await service.modifyProfile(name: nil, about: nil, avatar: [])
            XCTFail("expected invalidArgument")
        } catch let error as DomainError {
            XCTAssertEqual(error.code, .invalidArgument)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

}

private actor ProfileCommandRecorder: ModifyProfile {

    private(set) var lastCommand: ModifyProfileCommand?

    func modifyProfile(_ command: ModifyProfileCommand) async throws -> ProfileUpdateResult {
        lastCommand = command

        return ProfileUpdateResult(
            nameUpdated: command.name != nil,
            aboutUpdated: command.about != nil,
            avatarUpdated: command.avatar != nil
        )
    }

}
