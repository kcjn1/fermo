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
