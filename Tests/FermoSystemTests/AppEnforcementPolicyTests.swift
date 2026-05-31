import FermoCore
import FermoSystem
import Foundation
import Testing

@Test
func appEnforcementAllowsLaunchWhenNoSessionIsActive() throws {
    let now = Date(timeIntervalSince1970: 120_000)
    let policy = FermoPolicy()

    let decision = AppEnforcementPolicy().decision(
        for: AppLaunchContext(
            bundleIdentifier: "com.hnc.Discord",
            executablePath: "/Applications/Discord.app/Contents/MacOS/Discord"
        ),
        policy: policy,
        at: now
    )

    #expect(decision == .allow(reason: .noActiveSession))
}

@Test
func appEnforcementDeniesBlocklistedAppDuringActiveBlocklistSession() throws {
    let now = Date(timeIntervalSince1970: 120_100)
    let policy = try FocusContractDraft(
        taskTitle: "Ship billing memo",
        intendedOutcome: "Memo merged.",
        mode: .blocklist,
        rigor: .locked,
        duration: 3_600,
        blockedApps: [
            AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")
        ]
    ).activePolicy(startingAt: now)

    let decision = AppEnforcementPolicy().decision(
        for: AppLaunchContext(
            bundleIdentifier: " com.hnc.Discord ",
            executablePath: "/Applications/Discord.app/Contents/MacOS/Discord"
        ),
        policy: policy,
        at: now.addingTimeInterval(60)
    )

    #expect(decision == .deny(reason: .blockedByBlocklist))
}

@Test
func appEnforcementDecisionsAreNotCacheableForEndpointSecurity() throws {
    #expect(!AppEnforcementDecision.allow(reason: .noActiveSession).shouldCacheEndpointSecurityResponse)
    #expect(!AppEnforcementDecision.allow(reason: .notBlocked).shouldCacheEndpointSecurityResponse)
    #expect(!AppEnforcementDecision.deny(reason: .blockedByBlocklist).shouldCacheEndpointSecurityResponse)
    #expect(!AppEnforcementDecision.deny(reason: .notInFocusRoomAllowlist).shouldCacheEndpointSecurityResponse)
}

@Test
func appEnforcementDeniesUnapprovedAppDuringFocusRoomSession() throws {
    let now = Date(timeIntervalSince1970: 120_200)
    let policy = try FocusContractDraft(
        taskTitle: "Code Fermo",
        intendedOutcome: "Endpoint Security policy drafted.",
        mode: .focusRoom,
        rigor: .emergency,
        duration: 3_600,
        allowedDomains: [
            try DomainRule("developer.apple.com")
        ],
        allowedApps: [
            AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")
        ]
    ).activePolicy(startingAt: now)

    let decision = AppEnforcementPolicy().decision(
        for: AppLaunchContext(
            bundleIdentifier: "com.hnc.Discord",
            executablePath: "/Applications/Discord.app/Contents/MacOS/Discord"
        ),
        policy: policy,
        at: now.addingTimeInterval(60)
    )

    #expect(decision == .deny(reason: .notInFocusRoomAllowlist))
}

@Test
func appEnforcementAllowsApprovedFocusRoomAppAndCriticalSystemApps() throws {
    let now = Date(timeIntervalSince1970: 120_300)
    let policy = try FocusContractDraft(
        taskTitle: "Code Fermo",
        intendedOutcome: "Endpoint Security policy drafted.",
        mode: .focusRoom,
        rigor: .locked,
        duration: 3_600,
        allowedDomains: [
            try DomainRule("developer.apple.com")
        ],
        allowedApps: [
            AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")
        ]
    ).activePolicy(startingAt: now)
    let enforcer = AppEnforcementPolicy()

    let xcodeDecision = enforcer.decision(
        for: AppLaunchContext(bundleIdentifier: "com.apple.dt.Xcode"),
        policy: policy,
        at: now.addingTimeInterval(60)
    )
    let finderDecision = enforcer.decision(
        for: AppLaunchContext(bundleIdentifier: "com.apple.finder"),
        policy: policy,
        at: now.addingTimeInterval(60)
    )

    #expect(xcodeDecision == .allow(reason: .focusRoomAllowlist))
    #expect(finderDecision == .allow(reason: .criticalSystemApp))
}

@Test
func appEnforcementDeniesBlocklistedAppEvenWhenFocusRoomAllowsIt() throws {
    let now = Date(timeIntervalSince1970: 120_350)
    let policy = try FocusContractDraft(
        taskTitle: "Code Fermo",
        intendedOutcome: "Keep explicit blocks stronger than room allows.",
        mode: .focusRoom,
        rigor: .locked,
        duration: 3_600,
        blockedApps: [
            AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")
        ],
        allowedDomains: [
            try DomainRule("developer.apple.com")
        ],
        allowedApps: [
            AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")
        ]
    ).activePolicy(startingAt: now)

    let decision = AppEnforcementPolicy().decision(
        for: AppLaunchContext(bundleIdentifier: "com.apple.dt.Xcode"),
        policy: policy,
        at: now.addingTimeInterval(60)
    )

    #expect(decision == .deny(reason: .blockedByBlocklist))
}

@Test
func appEnforcementAllowsUnknownBundleIdentifierConservatively() throws {
    let now = Date(timeIntervalSince1970: 120_400)
    let policy = try FermoSampleData.appBlockingSpikePolicy(now: now)

    let decision = AppEnforcementPolicy().decision(
        for: AppLaunchContext(bundleIdentifier: nil, executablePath: "/usr/bin/env"),
        policy: policy,
        at: now.addingTimeInterval(60)
    )

    #expect(decision == .allow(reason: .missingBundleIdentifier))
}

@Test
func appEnforcementDeniesUnidentifiableLaunchDuringFocusRoomSession() throws {
    let now = Date(timeIntervalSince1970: 120_500)
    let policy = try FocusContractDraft(
        taskTitle: "Code Fermo",
        intendedOutcome: "Only allow-listed apps run inside the room.",
        mode: .focusRoom,
        rigor: .locked,
        duration: 3_600,
        allowedDomains: [try DomainRule("developer.apple.com")],
        allowedApps: [AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")]
    ).activePolicy(startingAt: now)

    let decision = AppEnforcementPolicy().decision(
        for: AppLaunchContext(bundleIdentifier: nil, executablePath: "/usr/bin/env"),
        policy: policy,
        at: now.addingTimeInterval(60)
    )

    // A Focus Room is allowlist-only; an app we cannot identify must not slip through.
    #expect(decision == .deny(reason: .notInFocusRoomAllowlist))
}

@Test
func appEnforcementMatchesBlocklistedAppRegardlessOfCase() throws {
    let now = Date(timeIntervalSince1970: 120_600)
    let policy = try FocusContractDraft(
        taskTitle: "Ship billing memo",
        intendedOutcome: "Memo merged.",
        mode: .blocklist,
        rigor: .locked,
        duration: 3_600,
        blockedApps: [AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")]
    ).activePolicy(startingAt: now)

    let decision = AppEnforcementPolicy().decision(
        for: AppLaunchContext(bundleIdentifier: "com.hnc.discord"),
        policy: policy,
        at: now.addingTimeInterval(60)
    )

    #expect(decision == .deny(reason: .blockedByBlocklist))
}
