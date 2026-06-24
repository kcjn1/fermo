import FermoCore
import FermoSystem
import Foundation
import Testing

@Test
func appGuardRuntimeDiagnosticReportsMissingSnapshot() {
    let snapshotURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoMissingAppGuardSnapshot-\(UUID().uuidString)")
        .appendingPathComponent(JSONFileFermoStore.defaultFileName)

    let diagnostic = AppGuardRuntimeDiagnostic.inspect(snapshotURL, at: Date(timeIntervalSince1970: 200_000))

    #expect(diagnostic.state == .missingSnapshot)
    #expect(diagnostic.snapshotPath == snapshotURL.path)
    #expect(diagnostic.activeSessionsCount == 0)
    #expect(diagnostic.protectedAppBundleIdentifiers == [])
    #expect(diagnostic.summary.contains("snapshot is missing"))
}

@Test
func appGuardRuntimeDiagnosticReportsActivePolicySnapshot() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoReadyAppGuardSnapshot-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let snapshotURL = directory.appendingPathComponent(JSONFileFermoStore.defaultFileName)
    let now = Date(timeIntervalSince1970: 210_000)
    let policy = try FocusContractDraft(
        taskTitle: "Validate App Guard",
        intendedOutcome: "Runtime matrix has app snapshot evidence.",
        mode: .blocklist,
        rigor: .locked,
        duration: 3_600,
        blockedApps: [
            AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord"),
            AppRule(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack")
        ]
    ).activePolicy(startingAt: now)
    try JSONFileFermoStore(url: snapshotURL).save(FermoSnapshot(policy: policy))

    let diagnostic = AppGuardRuntimeDiagnostic.inspect(snapshotURL, at: now.addingTimeInterval(60))

    #expect(diagnostic.state == .ready)
    #expect(diagnostic.snapshotPath == snapshotURL.path)
    #expect(diagnostic.activeSessionsCount == 1)
    #expect(diagnostic.protectedAppBundleIdentifiers == [
        "com.hnc.Discord",
        "com.tinyspeck.slackmacgap"
    ])
    #expect(diagnostic.summary.contains("1 active session"))
    #expect(diagnostic.summary.contains("2 protected apps"))
}
