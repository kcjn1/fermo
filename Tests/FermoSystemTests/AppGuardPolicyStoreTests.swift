import FermoCore
import FermoSystem
import Foundation
import Testing

@Test
func appGuardPolicyStoreLoadsPersistedPolicyAndDecidesLaunch() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoAppGuardPolicyStoreTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let snapshotURL = directory.appendingPathComponent(JSONFileFermoStore.defaultFileName)
    let now = Date(timeIntervalSince1970: 130_000)
    let policy = try FocusContractDraft(
        taskTitle: "Write ES guard",
        intendedOutcome: "App guard launch decisions are wired.",
        mode: .blocklist,
        rigor: .locked,
        duration: 3_600,
        blockedApps: [
            AppRule(bundleIdentifier: "com.hnc.Discord", displayName: "Discord")
        ]
    ).activePolicy(startingAt: now)
    try JSONFileFermoStore(url: snapshotURL).save(FermoSnapshot(policy: policy))

    let store = AppGuardPolicyStore(snapshotURL: snapshotURL)
    let decision = try store.decision(
        for: AppLaunchContext(bundleIdentifier: "com.hnc.Discord"),
        at: now.addingTimeInterval(60)
    )

    #expect(decision == .deny(reason: .blockedByBlocklist))
}

@Test
func appGuardPolicyStoreAllowsWhenSnapshotDoesNotExist() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoAppGuardPolicyStoreMissingTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = AppGuardPolicyStore(
        snapshotURL: directory.appendingPathComponent(JSONFileFermoStore.defaultFileName)
    )
    let decision = try store.decision(
        for: AppLaunchContext(bundleIdentifier: "com.hnc.Discord"),
        at: Date(timeIntervalSince1970: 130_100)
    )

    #expect(decision == .allow(reason: .noActiveSession))
}

@Test
func appGuardPolicyStoreBuildsDefaultURLFromAppGroup() throws {
    let identifier = "group.com.toolary.fermo.tests"
    let url = AppGuardPolicyStore.defaultSnapshotURL(appGroupIdentifier: identifier) { requestedIdentifier in
        #expect(requestedIdentifier == identifier)
        return URL(fileURLWithPath: "/tmp/FermoAppGuardPolicyStore")
    }

    #expect(url?.lastPathComponent == JSONFileFermoStore.defaultFileName)
    #expect(url?.deletingLastPathComponent().path == "/tmp/FermoAppGuardPolicyStore")
}
