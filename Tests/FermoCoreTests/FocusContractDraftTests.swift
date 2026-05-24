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
