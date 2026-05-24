import Foundation

public enum FermoSampleData {
    public static func helperPersistenceSpikePolicy(
        now: Date = Date(),
        duration: TimeInterval = 60 * 60,
        appBundleIdentifier: String = "com.apple.calculator",
        appDisplayName: String = "Calculator"
    ) throws -> FermoPolicy {
        let blocklist = Blocklist(
            name: "Helper Persistence Spike",
            domainRules: [
                try DomainRule("reddit.com"),
                try DomainRule("youtube.com")
            ],
            appRules: [
                AppRule(bundleIdentifier: appBundleIdentifier, displayName: appDisplayName)
            ]
        )
        let session = try FocusSession(
            title: "Helper Persistence Spike",
            contract: FocusContract(
                taskTitle: "Validate Helper Persistence",
                intendedOutcome: "Confirm an active diagnostic session can be restored by the background helper.",
                mode: .blocklist,
                rigor: .soft
            ),
            blocklistIDs: [blocklist.id],
            startsAt: now,
            duration: duration,
            lockedMode: false,
            rigor: .soft,
            state: .active
        )
        return FermoPolicy(blocklists: [blocklist], sessions: [session])
    }

    public static func appBlockingSpikePolicy(
        now: Date = Date(),
        duration: TimeInterval = 60 * 60,
        bundleIdentifier: String = "com.apple.calculator",
        displayName: String = "Calculator"
    ) throws -> FermoPolicy {
        let blocklist = Blocklist(
            name: "App Blocking Spike",
            appRules: [
                AppRule(bundleIdentifier: bundleIdentifier, displayName: displayName)
            ]
        )
        let session = try FocusSession(
            title: "App Blocking Spike",
            contract: FocusContract(
                taskTitle: "Validate App Blocking",
                intendedOutcome: "Confirm selected running apps are interrupted during an active focus session.",
                mode: .blocklist,
                rigor: .soft
            ),
            blocklistIDs: [blocklist.id],
            startsAt: now,
            duration: duration,
            lockedMode: false,
            rigor: .soft,
            state: .active
        )
        return FermoPolicy(blocklists: [blocklist], sessions: [session])
    }

    public static func websiteSpikePolicy(now: Date = Date(), duration: TimeInterval = 60 * 60) throws -> FermoPolicy {
        let blocklist = Blocklist(
            name: "Website Blocking Spike",
            domainRules: [
                try DomainRule("reddit.com"),
                try DomainRule("youtube.com")
            ]
        )
        let session = try FocusSession(
            title: "Website Blocking Spike",
            contract: FocusContract(
                taskTitle: "Validate Website Blocking",
                intendedOutcome: "Confirm reddit.com and youtube.com fail closed in common browsers.",
                mode: .blocklist,
                rigor: .soft
            ),
            blocklistIDs: [blocklist.id],
            startsAt: now,
            duration: duration,
            lockedMode: false,
            rigor: .soft,
            state: .active
        )
        return FermoPolicy(blocklists: [blocklist], sessions: [session])
    }

    public static func policy(now: Date = Date()) throws -> FermoPolicy {
        let blocklist = Blocklist(
            name: "Deep Work",
            domainRules: [
                try DomainRule("reddit.com"),
                try DomainRule("youtube.com")
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
                mode: .blocklist,
                rigor: .locked,
                allowedDomains: [],
                allowedApps: []
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
