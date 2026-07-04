import XCTest
@testable import FermoCore

final class EvidenceLedgerTests: XCTestCase {
    private func entry(task: String, endedAt: Date) -> EvidenceLogEntry {
        EvidenceLogEntry(
            sessionID: UUID(),
            taskTitle: task,
            intendedOutcome: "Outcome for \(task)",
            outcome: .completed,
            mode: .blocklist,
            rigor: .locked,
            startedAt: endedAt.addingTimeInterval(-3600),
            endedAt: endedAt,
            blockedDomains: ["reddit.com"],
            blockedApps: [],
            artifacts: [.note("done")]
        )
    }

    func testEmptyLedgerRendersPlaceholder() {
        let markdown = EvidenceMarkdownRenderer().renderLedger([])
        XCTAssertTrue(markdown.contains("No proof recorded yet."))
    }

    func testLedgerRendersNewestFirst() {
        let older = entry(task: "First", endedAt: Date(timeIntervalSince1970: 1_000))
        let newer = entry(task: "Second", endedAt: Date(timeIntervalSince1970: 5_000))
        let markdown = EvidenceMarkdownRenderer().renderLedger([older, newer])

        XCTAssertTrue(markdown.contains("2 recorded sessions."))
        let firstRange = try? XCTUnwrap(markdown.range(of: "# Second"))
        let secondRange = try? XCTUnwrap(markdown.range(of: "# First"))
        if let firstRange, let secondRange {
            XCTAssertTrue(firstRange.lowerBound < secondRange.lowerBound)
        }
    }
}
