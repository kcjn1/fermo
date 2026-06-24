import FermoCore
import Foundation
import Testing

@Test
func policyBlocksHostsAndAppsOnlyFromActiveEnabledBlocklists() throws {
    let blocklist = Blocklist(
        name: "Focus",
        domainRules: [try DomainRule("reddit.com")],
        appRules: [AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")]
    )
    let now = Date(timeIntervalSince1970: 20_000)
    let session = try FocusSession(
        title: "Focus",
        blocklistIDs: [blocklist.id],
        startsAt: now.addingTimeInterval(-60),
        duration: 600,
        state: .active
    )
    let policy = FermoPolicy(blocklists: [blocklist], sessions: [session])

    #expect(policy.shouldBlock(host: "old.reddit.com", at: now))
    #expect(!policy.shouldBlock(host: "example.com", at: now))
    #expect(policy.blockedAppBundleIdentifiers(at: now) == ["com.hnc.Discord"])
}

@Test
func appBlockingSpikePolicyTargetsSelectedBundleIdentifier() throws {
    let now = Date(timeIntervalSince1970: 41_000)
    let policy = try FermoSampleData.appBlockingSpikePolicy(
        now: now,
        bundleIdentifier: " com.apple.calculator ",
        displayName: " Calculator "
    )

    #expect(policy.blockedAppBundleIdentifiers(at: now) == ["com.apple.calculator"])
    #expect(policy.shouldInterruptApp(bundleIdentifier: "com.apple.calculator", at: now))
    #expect(!policy.shouldInterruptApp(bundleIdentifier: "com.apple.TextEdit", at: now))
}

@Test
func focusRoomBlockRulesStayMoreRestrictiveThanAllowlist() throws {
    let now = Date(timeIntervalSince1970: 42_000)
    let policy = try FocusContractDraft(
        taskTitle: "Ship Fermo",
        intendedOutcome: "Validate strict room semantics.",
        mode: .focusRoom,
        rigor: .locked,
        duration: 3_600,
        blockedDomains: [try DomainRule("github.com")],
        blockedApps: [AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")],
        allowedDomains: [try DomainRule("github.com")],
        allowedApps: [AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")]
    ).activePolicy(startingAt: now)

    #expect(policy.shouldBlock(host: "github.com", at: now))
    #expect(policy.shouldInterruptApp(bundleIdentifier: "com.apple.dt.Xcode", at: now))
}

@Test
func overlappingFocusRoomsUseIntersectionOfAllowedRules() throws {
    let now = Date(timeIntervalSince1970: 43_000)
    let firstRoom = try FocusContractDraft(
        taskTitle: "Write",
        intendedOutcome: "Draft finished.",
        mode: .focusRoom,
        rigor: .locked,
        duration: 3_600,
        allowedDomains: [try DomainRule("github.com")],
        allowedApps: [AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")]
    ).activePolicy(startingAt: now)
    let secondRoom = try FocusContractDraft(
        taskTitle: "Review",
        intendedOutcome: "Review finished.",
        mode: .focusRoom,
        rigor: .locked,
        duration: 3_600,
        allowedDomains: [
            try DomainRule("github.com"),
            try DomainRule("developer.apple.com")
        ],
        allowedApps: [
            AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode"),
            AppRule(bundleIdentifier: "com.apple.Terminal", displayName: "Terminal")
        ]
    ).activePolicy(startingAt: now)
    let policy = FermoPolicy(
        blocklists: firstRoom.blocklists + secondRoom.blocklists,
        sessions: firstRoom.sessions + secondRoom.sessions
    )

    #expect(!policy.shouldBlock(host: "github.com", at: now))
    #expect(policy.shouldBlock(host: "developer.apple.com", at: now))
    #expect(!policy.shouldInterruptApp(bundleIdentifier: "com.apple.dt.Xcode", at: now))
    #expect(policy.shouldInterruptApp(bundleIdentifier: "com.apple.Terminal", at: now))
}
