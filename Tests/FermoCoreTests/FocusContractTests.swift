import FermoCore
import Foundation
import Testing

@Test
func focusRoomBlocksUnapprovedDomainsAndAllowsRoomDomains() throws {
    let now = Date(timeIntervalSince1970: 30_000)
    let contract = FocusContract(
        taskTitle: "Write PRD",
        intendedOutcome: "Finish the Fermo PRD",
        mode: .focusRoom,
        rigor: .locked,
        allowedDomains: [try DomainRule("docs.google.com")]
    )
    let session = try FocusSession(
        title: "Write PRD",
        contract: contract,
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-60),
        duration: 1_800,
        state: .active
    )
    let policy = FermoPolicy(sessions: [session])

    #expect(!policy.shouldBlock(host: "docs.google.com", at: now))
    #expect(!policy.shouldBlock(host: "docs.google.com/document/u/0", at: now))
    #expect(policy.shouldBlock(host: "youtube.com", at: now))
    #expect(policy.shouldBlock(host: "example.com", at: now))
}

@Test
func focusRoomInterruptsAppsOutsideAllowedSet() throws {
    let now = Date(timeIntervalSince1970: 31_000)
    let contract = FocusContract(
        taskTitle: "Code",
        intendedOutcome: "Ship testable core",
        mode: .focusRoom,
        rigor: .locked,
        allowedApps: [
            AppRule(bundleIdentifier: "com.apple.Terminal", displayName: "Terminal")
        ]
    )
    let session = try FocusSession(
        title: "Code",
        contract: contract,
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-60),
        duration: 1_800,
        state: .active
    )
    let policy = FermoPolicy(sessions: [session])

    #expect(!policy.shouldInterruptApp(bundleIdentifier: "com.apple.Terminal", at: now))
    #expect(policy.shouldInterruptApp(bundleIdentifier: "com.hnc.Discord", at: now))
}

@Test
func emergencyRigorBlocksEarlyEndEvenWithoutLegacyLockedMode() throws {
    let now = Date(timeIntervalSince1970: 32_000)
    let session = try FocusSession(
        title: "Emergency Focus",
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-60),
        duration: 900,
        lockedMode: false,
        rigor: .emergency,
        state: .active
    )

    #expect(throws: LockedModeError.activeSessionLocked(until: session.endsAt)) {
        try LockedModeGuard().validate(.endSession, for: session, at: now)
    }
}

@Test
func defaultPresetsAreOfflineAndTaskTyped() throws {
    let presets = try FocusPresetLibrary.defaults()
    let coding = try #require(presets.first { $0.id == "coding" })
    let admin = try #require(presets.first { $0.id == "admin" })

    #expect(coding.mode == .focusRoom)
    #expect(coding.suggestedRigor == .locked)
    #expect(coding.allowedDomains.contains { $0.matches(host: "developer.apple.com") })
    #expect(admin.mode == .blocklist)
    #expect(admin.suggestedRigor == .soft)
}
