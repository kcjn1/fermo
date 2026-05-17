import Foundation

public enum FermoSampleData {
    public static func policy(now: Date = Date()) throws -> FermoPolicy {
        let blocklist = Blocklist(
            name: "Deep Work",
            domainRules: [
                try DomainRule("reddit.com"),
                try DomainRule("youtube.com"),
                try DomainRule("x.com")
            ],
            appRules: [
                AppRule(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack"),
                AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")
            ]
        )
        let session = try FocusSession(
            title: "Dogfood Focus",
            contract: FocusContract(
                taskTitle: "Dogfood Fermo",
                intendedOutcome: "Validate the contract-first flow and record one concrete result.",
                mode: .focusRoom,
                rigor: .locked,
                allowedDomains: [try DomainRule("github.com"), try DomainRule("developer.apple.com")],
                allowedApps: [AppRule(bundleIdentifier: "com.apple.Terminal", displayName: "Terminal")]
            ),
            blocklistIDs: [blocklist.id],
            startsAt: now.addingTimeInterval(-60),
            duration: 50 * 60,
            lockedMode: true,
            rigor: .locked,
            state: .active
        )
        return FermoPolicy(blocklists: [blocklist], sessions: [session])
    }
}
