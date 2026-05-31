import FermoCore
import FermoSystem
import Foundation
import Testing

@Test
func contentFilterRuntimeDiagnosticReportsMissingSnapshot() {
    let snapshotURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoMissingContentFilterSnapshot-\(UUID().uuidString)")
        .appendingPathComponent(ContentFilterRuleSnapshot.defaultFileName)

    let diagnostic = ContentFilterRuntimeDiagnostic.inspect(snapshotURL, at: Date(timeIntervalSince1970: 700_000))

    #expect(diagnostic.state == .missingSnapshot)
    #expect(diagnostic.snapshotPath == snapshotURL.path)
    #expect(diagnostic.activeSessionsCount == 0)
    #expect(diagnostic.blockedDomains == [])
    #expect(diagnostic.allowedDomains == [])
    #expect(diagnostic.summary.contains("snapshot is missing"))
}

@Test
func contentFilterRuntimeDiagnosticReportsExpiredSnapshot() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoExpiredContentFilterSnapshot-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let now = Date(timeIntervalSince1970: 710_000)
    let snapshotURL = directory.appendingPathComponent(ContentFilterRuleSnapshot.defaultFileName)
    try ContentFilterRuleSnapshotStore(fileURL: snapshotURL).write(
        try ContentFilterRuleSnapshot.redditYouTubeSpike(now: now.addingTimeInterval(-3_600), duration: 600)
    )

    let diagnostic = ContentFilterRuntimeDiagnostic.inspect(snapshotURL, at: now)

    #expect(diagnostic.state == .expiredSnapshot)
    #expect(diagnostic.activeSessionsCount == 0)
    #expect(diagnostic.blockedDomains == ["reddit.com", "youtube.com"])
    #expect(diagnostic.summary.contains("expired"))
}

@Test
func contentFilterRuntimeDiagnosticReportsActiveBlocklistSnapshot() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoReadyContentFilterSnapshot-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let now = Date(timeIntervalSince1970: 720_000)
    let snapshotURL = directory.appendingPathComponent(ContentFilterRuleSnapshot.defaultFileName)
    let policy = try FocusContractDraft(
        taskTitle: "Validate Content Filter",
        intendedOutcome: "Runtime matrix has website snapshot evidence.",
        mode: .blocklist,
        rigor: .locked,
        duration: 3_600,
        blockedDomains: [
            try DomainRule("reddit.com"),
            try DomainRule("youtube.com")
        ]
    ).activePolicy(startingAt: now)
    try ContentFilterRuleSnapshotStore(fileURL: snapshotURL).write(
        ContentFilterRuleSnapshot(policy: policy, at: now)
    )

    let diagnostic = ContentFilterRuntimeDiagnostic.inspect(snapshotURL, at: now.addingTimeInterval(60))

    #expect(diagnostic.state == .ready)
    #expect(diagnostic.mode == .blocklist)
    #expect(diagnostic.activeSessionsCount == 1)
    #expect(diagnostic.blockedDomains == ["reddit.com", "youtube.com"])
    #expect(diagnostic.allowedDomains == [])
    #expect(diagnostic.summary.contains("1 active session"))
    #expect(diagnostic.summary.contains("2 blocked domains"))
}

@Test
func contentFilterRuntimeDiagnosticReportsFocusRoomSnapshot() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoFocusRoomContentFilterSnapshot-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let now = Date(timeIntervalSince1970: 730_000)
    let snapshotURL = directory.appendingPathComponent(ContentFilterRuleSnapshot.defaultFileName)
    let policy = try FocusContractDraft(
        taskTitle: "Validate Focus Room",
        intendedOutcome: "Runtime matrix has focus room snapshot evidence.",
        mode: .focusRoom,
        rigor: .locked,
        duration: 3_600,
        blockedDomains: [try DomainRule("youtube.com")],
        allowedDomains: [try DomainRule("developer.apple.com")]
    ).activePolicy(startingAt: now)
    try ContentFilterRuleSnapshotStore(fileURL: snapshotURL).write(
        ContentFilterRuleSnapshot(policy: policy, at: now)
    )

    let diagnostic = ContentFilterRuntimeDiagnostic.inspect(snapshotURL, at: now.addingTimeInterval(60))

    #expect(diagnostic.state == .ready)
    #expect(diagnostic.mode == .focusRoom)
    #expect(diagnostic.blockedDomains == ["youtube.com"])
    #expect(diagnostic.allowedDomains == ["developer.apple.com"])
    #expect(diagnostic.summary.contains("1 allowed domain"))
    #expect(diagnostic.summary.contains("1 explicit blocked domain"))
}
