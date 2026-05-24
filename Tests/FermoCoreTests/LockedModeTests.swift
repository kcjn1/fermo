import FermoCore
import Foundation
import Testing

@Test
func lockedModeBlocksEarlyEndForActiveSession() throws {
    let now = Date(timeIntervalSince1970: 10_000)
    let session = try FocusSession(
        title: "Locked",
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-60),
        duration: 600,
        lockedMode: true,
        state: .active
    )

    #expect(throws: LockedModeError.activeSessionLocked(until: session.endsAt)) {
        try LockedModeGuard().validate(.endSession, for: session, at: now)
    }
}

@Test
func lockedModeAllowsChangesAfterSessionEnds() throws {
    let now = Date(timeIntervalSince1970: 10_000)
    let session = try FocusSession(
        title: "Ended",
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-600),
        duration: 300,
        lockedMode: true,
        state: .active
    )

    try LockedModeGuard().validate(.endSession, for: session, at: now)
}

@Test
func lockedModePolicyGuardBlocksWeakeningAnyActiveProtectedSession() throws {
    let now = Date(timeIntervalSince1970: 10_500)
    let soft = try FocusSession(
        title: "Soft",
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-60),
        duration: 600,
        rigor: .soft,
        state: .active
    )
    let locked = try FocusSession(
        title: "Locked",
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-60),
        duration: 600,
        rigor: .locked,
        state: .active
    )
    let policy = FermoPolicy(sessions: [soft, locked])

    #expect(throws: LockedModeError.activeSessionLocked(until: locked.endsAt)) {
        try LockedModeGuard().validate(.editSessionBlocklists, for: policy, at: now)
    }
}

@Test
func diagnosticSpikePoliciesRemainReversible() throws {
    let now = Date(timeIntervalSince1970: 11_000)
    let policies = try [
        FermoSampleData.websiteSpikePolicy(now: now),
        FermoSampleData.appBlockingSpikePolicy(now: now),
        FermoSampleData.helperPersistenceSpikePolicy(now: now)
    ]

    for policy in policies {
        try LockedModeGuard().validate(.endSession, for: policy, at: now)
    }
}

@Test
func realLockedContractStillBlocksNormalEarlyStop() throws {
    let now = Date(timeIntervalSince1970: 12_000)
    let policy = try FocusContractDraft(
        taskTitle: "Ship the hard thing",
        intendedOutcome: "Complete one concrete protected task.",
        mode: .blocklist,
        rigor: .locked,
        duration: 1_800,
        blockedDomains: [
            try DomainRule("reddit.com")
        ]
    ).activePolicy(startingAt: now)

    #expect(throws: LockedModeError.activeSessionLocked(until: policy.sessions[0].endsAt)) {
        try LockedModeGuard().validate(.endSession, for: policy, at: now)
    }
}
