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
