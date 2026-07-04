import XCTest
@testable import FermoCore

final class PolicyEditorTests: XCTestCase {
    private let editor = PolicyEditor()

    private func policyWithBlocklist() throws -> (FermoPolicy, UUID) {
        let blocklist = Blocklist(name: "Distractions")
        let policy = FermoPolicy(blocklists: [blocklist])
        return (policy, blocklist.id)
    }

    private func lockedPolicy(referencing blocklistID: UUID) throws -> FermoPolicy {
        var (policy, _) = try policyWithBlocklist()
        policy.blocklists[0] = Blocklist(id: blocklistID, name: "Distractions", domainRules: [try DomainRule("reddit.com")])
        let session = try FocusSession(
            title: "Locked work",
            blocklistIDs: [blocklistID],
            startsAt: Date().addingTimeInterval(-60),
            duration: 3600,
            lockedMode: true,
            rigor: .locked,
            state: .active
        )
        policy.sessions = [session]
        return policy
    }

    func testAddDomainAppendsNormalizedRule() throws {
        let (policy, id) = try policyWithBlocklist()
        let next = try editor.addDomain("https://Reddit.com/r/all", to: id, in: policy)
        XCTAssertEqual(next.blocklists[0].domainRules.map(\.normalizedPattern), ["reddit.com"])
    }

    func testAddDuplicateDomainThrows() throws {
        let (policy, id) = try policyWithBlocklist()
        let once = try editor.addDomain("reddit.com", to: id, in: policy)
        XCTAssertThrowsError(try editor.addDomain("reddit.com", to: id, in: once)) { error in
            XCTAssertEqual(error as? PolicyEditError, .duplicateDomain("reddit.com"))
        }
    }

    func testAddInvalidDomainThrows() throws {
        let (policy, id) = try policyWithBlocklist()
        XCTAssertThrowsError(try editor.addDomain("not a domain", to: id, in: policy))
    }

    func testAddAppRuleAndDuplicateRejected() throws {
        let (policy, id) = try policyWithBlocklist()
        let rule = AppRule(bundleIdentifier: "com.google.Chrome", displayName: "Chrome")
        let next = try editor.addApp(rule, to: id, in: policy)
        XCTAssertEqual(next.blocklists[0].appRules, [rule])
        XCTAssertThrowsError(try editor.addApp(rule, to: id, in: next)) { error in
            XCTAssertEqual(error as? PolicyEditError, .duplicateApp("com.google.Chrome"))
        }
    }

    func testStrengtheningAllowedDuringLockedSession() throws {
        let (base, id) = try policyWithBlocklist()
        _ = base
        let locked = try lockedPolicy(referencing: id)
        // Adding another blocked domain strengthens protection and must be allowed.
        let next = try editor.addDomain("youtube.com", to: id, in: locked)
        XCTAssertEqual(next.blocklists[0].domainRules.count, 2)
    }

    func testRemovingDomainDuringLockedSessionThrows() throws {
        let (_, id) = try policyWithBlocklist()
        let locked = try lockedPolicy(referencing: id)
        XCTAssertThrowsError(try editor.removeDomain(normalizedPattern: "reddit.com", from: id, in: locked)) { error in
            guard case LockedModeError.activeSessionLocked = error else {
                return XCTFail("expected locked error, got \(error)")
            }
        }
    }

    func testDeleteBlocklistDuringLockedSessionThrows() throws {
        let (_, id) = try policyWithBlocklist()
        let locked = try lockedPolicy(referencing: id)
        XCTAssertThrowsError(try editor.deleteBlocklist(id, in: locked))
    }

    func testRemoveDomainWhenUnlockedSucceeds() throws {
        var (policy, id) = try policyWithBlocklist()
        policy = try editor.addDomain("reddit.com", to: id, in: policy)
        let next = try editor.removeDomain(normalizedPattern: "reddit.com", from: id, in: policy)
        XCTAssertTrue(next.blocklists[0].domainRules.isEmpty)
    }

    func testCreateAndRenameBlocklist() throws {
        var policy = FermoPolicy()
        policy = try editor.createBlocklist(named: "Social", in: policy)
        XCTAssertEqual(policy.blocklists.count, 1)
        let id = policy.blocklists[0].id
        policy = try editor.renameBlocklist(id, to: "Social Media", in: policy)
        XCTAssertEqual(policy.blocklists[0].name, "Social Media")
        XCTAssertThrowsError(try editor.createBlocklist(named: "   ", in: policy))
    }
}
