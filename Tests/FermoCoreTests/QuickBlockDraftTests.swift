import XCTest
@testable import FermoCore

final class QuickBlockDraftTests: XCTestCase {
    func testActivePolicyEnforcesRoomAsBlocklist() throws {
        let room = Blocklist(
            name: "Focus",
            domainRules: [try DomainRule("reddit.com")],
            appRules: [AppRule(bundleIdentifier: "com.google.Chrome", displayName: "Chrome")],
            isEnabled: false
        )
        let draft = QuickBlockDraft(blocklist: room, duration: 1800, rigor: .locked)
        let start = Date()
        let policy = try draft.activePolicy(startingAt: start)

        XCTAssertEqual(policy.blocklists.count, 1)
        XCTAssertTrue(policy.blocklists[0].isEnabled)
        XCTAssertTrue(policy.shouldBlock(host: "reddit.com", at: start.addingTimeInterval(1)))
        XCTAssertTrue(policy.blockedAppBundleIdentifiers(at: start.addingTimeInterval(1)).contains("com.google.Chrome"))
        XCTAssertNil(policy.sessions.first?.contract)
        XCTAssertEqual(policy.sessions.first?.rigor, .locked)
        XCTAssertTrue(policy.sessions.first?.lockedMode == true)
    }

    func testEmptyRoomThrows() throws {
        let room = Blocklist(name: "Empty")
        let draft = QuickBlockDraft(blocklist: room, duration: 600)
        XCTAssertThrowsError(try draft.activePolicy()) { error in
            XCTAssertEqual(error as? QuickBlockError, .emptyRoom)
        }
    }

    func testPresetAsBlocklistUsesBlockedRules() throws {
        let preset = try FocusPresetLibrary.defaults().first { $0.id == "admin" }
        let room = try XCTUnwrap(preset).asBlocklist()
        XCTAssertFalse(room.domainRules.isEmpty)
    }
}
