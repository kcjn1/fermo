import FermoCore
import Foundation
import Testing

@Test
func policyEditorAddsValidatedDeduplicatedBlocklist() throws {
    let policy = FermoPolicy()
    let draft = BlocklistEditorDraft(
        name: "  Deep Work  ",
        domainPatterns: [
            "https://www.reddit.com/r/swift",
            "reddit.com",
            "  "
        ],
        appRules: [
            EditableAppRule(bundleIdentifier: " com.hnc.Discord ", displayName: " Discord "),
            EditableAppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")
        ],
        isEnabled: true
    )

    let nextPolicy = try PolicyEditor().addBlocklist(draft, to: policy)
    let blocklist = try #require(nextPolicy.blocklists.first)

    #expect(blocklist.name == "Deep Work")
    #expect(blocklist.domainRules.map(\.normalizedPattern) == ["www.reddit.com", "reddit.com"])
    #expect(blocklist.appRules == [
        AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")
    ])
}

@Test
func policyEditorCollapsesSameNormalizedDomainLikeContractDraft() throws {
    // Regression: PolicyEditor used plain Hashable dedup, so two patterns that normalize to the
    // same host (e.g. "https://reddit.com/r/swift" and "reddit.com") survived as duplicates.
    // It now shares deduplicatedByNormalizedPattern() with FocusContractRuleDraft.
    let nextPolicy = try PolicyEditor().addBlocklist(
        BlocklistEditorDraft(
            name: "Deep Work",
            domainPatterns: ["https://reddit.com/r/swift", "reddit.com"]
        ),
        to: FermoPolicy()
    )
    let blocklist = try #require(nextPolicy.blocklists.first)
    #expect(blocklist.domainRules.map(\.normalizedPattern) == ["reddit.com"])
}

@Test
func policyEditorCollapsesCaseAndDisplayNameVariantAppRules() throws {
    // Regression: AppRule identity was case-sensitive and included displayName, so the same
    // app under different casing/labels survived as duplicates.
    let nextPolicy = try PolicyEditor().addBlocklist(
        BlocklistEditorDraft(
            name: "Deep Work",
            appRules: [
                EditableAppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord"),
                EditableAppRule(bundleIdentifier: "com.hnc.discord", displayName: "discord")
            ]
        ),
        to: FermoPolicy()
    )
    let blocklist = try #require(nextPolicy.blocklists.first)
    #expect(blocklist.appRules.count == 1)
    #expect(blocklist.appRules.first?.normalizedBundleIdentifier == "com.hnc.discord")
}

@Test
func policyMatchesBlockedAppRegardlessOfBundleIdentifierCase() throws {
    let now = Date(timeIntervalSince1970: 94_000)
    let policy = try FocusContractDraft(
        taskTitle: "Locked work",
        intendedOutcome: "Block Discord no matter how its bundle id is cased.",
        mode: .blocklist,
        rigor: .locked,
        duration: 1_800,
        blockedApps: [AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")]
    ).activePolicy(startingAt: now)

    #expect(policy.shouldInterruptApp(bundleIdentifier: "com.hnc.discord", at: now))
    #expect(policy.shouldInterruptApp(bundleIdentifier: "COM.HNC.DISCORD", at: now))
}

@Test
func policyEditorUpdatesExistingBlocklistAndPreservesIdentifier() throws {
    let blocklistID = UUID()
    let policy = FermoPolicy(blocklists: [
        Blocklist(id: blocklistID, name: "Old", domainRules: [try DomainRule("x.com")])
    ])

    let nextPolicy = try PolicyEditor().updateBlocklist(
        id: blocklistID,
        with: BlocklistEditorDraft(
            name: "Updated",
            domainPatterns: ["github.com"],
            appRules: [EditableAppRule(bundleIdentifier: "com.apple.dt.Xcode")]
        ),
        in: policy
    )
    let blocklist = try #require(nextPolicy.blocklists.first)

    #expect(blocklist.id == blocklistID)
    #expect(blocklist.name == "Updated")
    #expect(blocklist.domainRules.map(\.normalizedPattern) == ["github.com"])
    #expect(blocklist.appRules == [
        AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "com.apple.dt.Xcode")
    ])
}

@Test
func policyEditorDeletesBlocklistAndRemovesSessionReference() throws {
    let blocklistID = UUID()
    let session = try FocusSession(
        title: "Soft session",
        blocklistIDs: [blocklistID],
        startsAt: Date(timeIntervalSince1970: 140_000),
        duration: 3_600,
        rigor: .soft,
        state: .active
    )
    let policy = FermoPolicy(
        blocklists: [Blocklist(id: blocklistID, name: "Distractions")],
        sessions: [session]
    )

    let nextPolicy = try PolicyEditor().deleteBlocklist(
        id: blocklistID,
        from: policy,
        at: session.startsAt.addingTimeInterval(60)
    )

    #expect(nextPolicy.blocklists.isEmpty)
    #expect(nextPolicy.sessions.first?.blocklistIDs.isEmpty == true)
}

@Test
func policyEditorBlocksRuleWeakeningDuringLockedSession() throws {
    let now = Date(timeIntervalSince1970: 140_100)
    let policy = try FocusContractDraft(
        taskTitle: "Locked work",
        intendedOutcome: "Finish implementation.",
        mode: .blocklist,
        rigor: .locked,
        duration: 3_600,
        blockedDomains: [try DomainRule("reddit.com")]
    ).activePolicy(startingAt: now)
    let blocklistID = try #require(policy.blocklists.first?.id)

    #expect(throws: LockedModeError.activeSessionLocked(until: now.addingTimeInterval(3_600))) {
        try PolicyEditor().updateBlocklist(
            id: blocklistID,
            with: BlocklistEditorDraft(name: "Weakened"),
            in: policy,
            at: now.addingTimeInterval(60)
        )
    }

    #expect(throws: LockedModeError.activeSessionLocked(until: now.addingTimeInterval(3_600))) {
        try PolicyEditor().deleteBlocklist(
            id: blocklistID,
            from: policy,
            at: now.addingTimeInterval(60)
        )
    }
}

@Test
func policyEditorRejectsInvalidDrafts() throws {
    #expect(throws: PolicyEditorError.emptyBlocklistName) {
        try PolicyEditor().addBlocklist(
            BlocklistEditorDraft(name: " ", domainPatterns: ["github.com"]),
            to: FermoPolicy()
        )
    }

    #expect(throws: PolicyEditorError.emptyAppBundleIdentifier) {
        try PolicyEditor().addBlocklist(
            BlocklistEditorDraft(
                name: "Apps",
                appRules: [EditableAppRule(bundleIdentifier: "", displayName: "Discord")]
            ),
            to: FermoPolicy()
        )
    }

    #expect(throws: FermoValidationError.invalidDomainRule("not-a-domain")) {
        try PolicyEditor().addBlocklist(
            BlocklistEditorDraft(name: "Domains", domainPatterns: ["not-a-domain"]),
            to: FermoPolicy()
        )
    }
}
