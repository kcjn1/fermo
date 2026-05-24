import FermoCore
import Foundation
import Testing

@Test
func fermoSnapshotProjectsToAndFromPolicy() throws {
    let now = Date(timeIntervalSince1970: 70_000)
    let policy = try FermoSampleData.helperPersistenceSpikePolicy(now: now, duration: 900)

    let snapshot = FermoSnapshot(policy: policy)

    #expect(snapshot.policy == policy)
    #expect(snapshot.sessions.first?.isActive(at: now) == true)
    #expect(snapshot.policy.shouldBlock(host: "reddit.com", at: now))
    #expect(snapshot.policy.shouldInterruptApp(bundleIdentifier: "com.apple.calculator", at: now))
}

@Test
func jsonFileFermoStoreRoundTripsHelperPersistenceSnapshot() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("FermoSnapshotStoreTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = JSONFileFermoStore(url: directory.appendingPathComponent(JSONFileFermoStore.defaultFileName))
    let snapshot = FermoSnapshot(
        policy: try FermoSampleData.helperPersistenceSpikePolicy(
            now: Date(timeIntervalSince1970: 70_500),
            duration: 600
        )
    )

    try store.save(snapshot)

    #expect(try store.load() == snapshot)
}
