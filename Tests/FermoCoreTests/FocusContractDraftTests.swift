import FermoCore
import Foundation
import Testing

@Test
func focusContractDraftBuildsActiveBlocklistPolicyFromPreset() throws {
    let preset = FocusPreset(
        id: "dogfood",
        name: "Dogfood",
        mode: .blocklist,
        suggestedRigor: .locked,
        blockedDomains: [
            try DomainRule("reddit.com"),
            try DomainRule("youtube.com")
        ],
        blockedApps: [
            AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")
        ]
    )
    let now = Date(timeIntervalSince1970: 80_000)
    let draft = FocusContractDraft(
        preset: preset,
        taskTitle: " Ship Fermo dogfood ",
        intendedOutcome: "Start a real contract from the UI.",
        duration: 1_800
    )

    let policy = try draft.activePolicy(startingAt: now)
    let session = try #require(policy.sessions.first)

    #expect(session.isActive(at: now))
    #expect(session.contract?.taskTitle == "Ship Fermo dogfood")
    #expect(session.contract?.mode == .blocklist)
    #expect(session.rigor == .locked)
    #expect(policy.shouldBlock(host: "old.reddit.com", at: now))
    #expect(policy.shouldInterruptApp(bundleIdentifier: "com.hnc.Discord", at: now))
}

@Test
func focusContractDraftBuildsScheduledPolicyForStartLater() throws {
    let startsAt = Date(timeIntervalSince1970: 90_000)
    let draft = FocusContractDraft(
        taskTitle: "Write launch checklist",
        intendedOutcome: "Checklist is ready for signing pass.",
        mode: .blocklist,
        rigor: .locked,
        duration: 1_800,
        blockedDomains: [
            try DomainRule("reddit.com")
        ]
    )

    let policy = try draft.scheduledPolicy(startingAt: startsAt)
    let session = try #require(policy.sessions.first)

    #expect(session.state == .scheduled)
    #expect(session.startsAt == startsAt)
    #expect(policy.activeSessions(at: startsAt).isEmpty)
    #expect(policy.blocklists.count == 1)
}

@Test
func dueSessionActivatorActivatesScheduledSessionsInsideTheirWindow() throws {
    let startsAt = Date(timeIntervalSince1970: 91_000)
    let policy = try FocusContractDraft(
        taskTitle: "Write launch checklist",
        intendedOutcome: "Checklist is ready for signing pass.",
        mode: .blocklist,
        rigor: .locked,
        duration: 1_800,
        blockedDomains: [
            try DomainRule("reddit.com")
        ]
    )
    .scheduledPolicy(startingAt: startsAt)

    let result = DueSessionActivator().activatingDueSessions(
        in: policy,
        at: startsAt.addingTimeInterval(60)
    )

    #expect(result.didChange)
    #expect(result.policy.sessions.first?.state == .active)
    #expect(result.policy.shouldBlock(host: "old.reddit.com", at: startsAt.addingTimeInterval(60)))
}

@Test
func dueSessionActivatorCancelsMissedScheduledSessions() throws {
    let startsAt = Date(timeIntervalSince1970: 92_000)
    let policy = try FocusContractDraft(
        taskTitle: "Write launch checklist",
        intendedOutcome: "Checklist is ready for signing pass.",
        mode: .blocklist,
        rigor: .locked,
        duration: 1_800,
        blockedDomains: [
            try DomainRule("reddit.com")
        ]
    )
    .scheduledPolicy(startingAt: startsAt)

    let result = DueSessionActivator().activatingDueSessions(
        in: policy,
        at: startsAt.addingTimeInterval(1_900)
    )

    #expect(result.didChange)
    #expect(result.policy.sessions.first?.state == .cancelled)
    #expect(result.policy.activeSessions(at: startsAt.addingTimeInterval(1_900)).isEmpty)
}

@Test
func focusContractDraftBuildsFocusRoomPolicyWithAllowedRules() throws {
    let now = Date(timeIntervalSince1970: 80_500)
    let draft = FocusContractDraft(
        taskTitle: "Write design critique",
        intendedOutcome: "Record the strongest product gaps.",
        mode: .focusRoom,
        rigor: .emergency,
        duration: 3_600,
        blockedDomains: [
            try DomainRule("reddit.com")
        ],
        allowedDomains: [
            try DomainRule("docs.google.com")
        ],
        allowedApps: [
            AppRule(bundleIdentifier: "md.obsidian", displayName: "Obsidian")
        ]
    )

    let policy = try draft.activePolicy(startingAt: now)
    let session = try #require(policy.sessions.first)

    #expect(session.lockedMode)
    #expect(session.contract?.mode == .focusRoom)
    #expect(!policy.shouldBlock(host: "docs.google.com", at: now))
    #expect(policy.shouldBlock(host: "youtube.com", at: now))
    #expect(!policy.shouldInterruptApp(bundleIdentifier: "md.obsidian", at: now))
    #expect(policy.shouldInterruptApp(bundleIdentifier: "com.hnc.Discord", at: now))
}

@Test
func focusContractRuleDraftResolvesCustomDeduplicatedRules() throws {
    let ruleDraft = FocusContractRuleDraft(
        blockedDomainPatterns: [
            " https://reddit.com/r/swift ",
            "reddit.com"
        ],
        blockedAppRules: [
            EditableAppRule(bundleIdentifier: " com.hnc.Discord ", displayName: " Discord "),
            EditableAppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")
        ],
        allowedDomainPatterns: [
            "https://docs.google.com/document/d/123",
            "docs.google.com"
        ],
        allowedAppRules: [
            EditableAppRule(bundleIdentifier: " md.obsidian ", displayName: " Obsidian "),
            EditableAppRule(bundleIdentifier: "md.obsidian", displayName: "Obsidian")
        ]
    )

    let rules = try ruleDraft.resolved()

    #expect(rules.blockedDomains.map(\.normalizedPattern) == ["reddit.com"])
    #expect(rules.blockedApps == [AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")])
    #expect(rules.allowedDomains.map(\.normalizedPattern) == ["docs.google.com"])
    #expect(rules.allowedApps == [AppRule(bundleIdentifier: "md.obsidian", displayName: "Obsidian")])
}

@Test
func focusContractRuleDraftRejectsAppNamesWithoutBundleIdentifiers() throws {
    let ruleDraft = FocusContractRuleDraft(
        allowedAppRules: [
            EditableAppRule(bundleIdentifier: "", displayName: "Obsidian")
        ]
    )

    #expect(throws: FocusContractRuleDraftError.emptyAppBundleIdentifier) {
        try ruleDraft.resolved()
    }
}

@Test
func focusContractDraftRejectsMissingRules() throws {
    let blockDraft = FocusContractDraft(
        taskTitle: "Admin",
        intendedOutcome: "Clean inbox.",
        mode: .blocklist,
        rigor: .soft,
        duration: 900
    )
    let roomDraft = FocusContractDraft(
        taskTitle: "Plan",
        intendedOutcome: "Write next milestone.",
        mode: .focusRoom,
        rigor: .locked,
        duration: 900
    )

    #expect(throws: FocusContractDraftError.missingBlockRules) {
        try blockDraft.activePolicy()
    }
    #expect(throws: FocusContractDraftError.missingFocusRoomAllowRules) {
        try roomDraft.activePolicy()
    }
}
