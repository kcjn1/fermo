import FermoCore
import Foundation
import Testing

@Test
func evidenceLogRendersMarkdownProofAndFocusRoom() {
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!
    let start = Date(timeIntervalSince1970: 40_000)
    let end = start.addingTimeInterval(1_800)
    let entry = EvidenceLogEntry(
        sessionID: sessionID,
        createdAt: end,
        taskTitle: "Finish Fermo core",
        intendedOutcome: "Implement focus contracts and evidence log.",
        outcome: .completed,
        mode: .focusRoom,
        rigor: .locked,
        startedAt: start,
        endedAt: end,
        blockedDomains: ["youtube.com", "reddit.com"],
        blockedApps: ["com.hnc.Discord"],
        allowedDomains: ["github.com"],
        allowedApps: ["com.apple.Terminal"],
        artifacts: [
            .note("Core tests pass."),
            .commitHash("abc1234")
        ],
        nextStep: "Run signed Network Extension spike."
    )

    let markdown = EvidenceMarkdownRenderer().render(entry)

    #expect(markdown.contains("# Finish Fermo core"))
    #expect(markdown.contains("## Intended Outcome"))
    #expect(markdown.contains("- Commit: `abc1234`"))
    #expect(markdown.contains("- `github.com`"))
    #expect(markdown.contains("Run signed Network Extension spike."))
}
