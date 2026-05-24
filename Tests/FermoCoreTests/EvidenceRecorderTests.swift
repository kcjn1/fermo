import FermoCore
import Foundation
import Testing

@Test
func evidenceRecorderCompletesSoftSessionAndAppendsMarkdownReadyEntry() throws {
    let now = Date(timeIntervalSince1970: 90_000)
    let draft = FocusContractDraft(
        taskTitle: "Write release note",
        intendedOutcome: "One honest pre-beta note.",
        mode: .blocklist,
        rigor: .soft,
        duration: 1_800,
        blockedDomains: [
            try DomainRule("youtube.com")
        ]
    )
    let policy = try draft.activePolicy(startingAt: now)
    let session = try #require(policy.sessions.first)
    let evidence = EvidenceDraft(
        outcome: .completed,
        note: "Drafted and reviewed.",
        commitHash: "def5678",
        nextStep: "Run signed browser checks."
    )

    let nextPolicy = try EvidenceRecorder().record(evidence, for: session.id, in: policy, at: now.addingTimeInterval(300))
    let completed = try #require(nextPolicy.sessions.first)
    let entry = try #require(nextPolicy.evidenceLog.first)
    let markdown = EvidenceMarkdownRenderer().render(entry)

    #expect(completed.state == .completed)
    #expect(entry.outcome == .completed)
    #expect(markdown.contains("- Commit: `def5678`"))
    #expect(markdown.contains("Run signed browser checks."))
}

@Test
func evidenceRecorderRequiresBreakGlassForActiveLockedSession() throws {
    let now = Date(timeIntervalSince1970: 91_000)
    let policy = try FocusContractDraft(
        taskTitle: "Locked work",
        intendedOutcome: "Stay protected until the timer ends.",
        mode: .blocklist,
        rigor: .locked,
        duration: 1_800,
        blockedDomains: [
            try DomainRule("reddit.com")
        ]
    ).activePolicy(startingAt: now)
    let session = try #require(policy.sessions.first)

    #expect(throws: EvidenceRecordError.lockedSessionStillActive(until: session.endsAt)) {
        try EvidenceRecorder().record(
            EvidenceDraft(outcome: .completed, note: "Trying to end early."),
            for: session.id,
            in: policy,
            at: now.addingTimeInterval(60)
        )
    }

    let broken = try EvidenceRecorder().record(
        EvidenceDraft(
            outcome: .breakGlass,
            note: "Need to handle an urgent incident.",
            breakGlassReason: "Production support interruption."
        ),
        for: session.id,
        in: policy,
        at: now.addingTimeInterval(60)
    )

    #expect(broken.sessions.first?.state == .cancelled)
    #expect(broken.evidenceLog.first?.outcome == .breakGlass)
    #expect(broken.evidenceLog.first?.artifacts.contains(.breakGlassReason("Production support interruption.")) == true)
}
