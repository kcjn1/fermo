import FermoCore
import Foundation
import Testing

@Test
func contentFilterSnapshotBlocksOnlyActiveBlocklistDomains() throws {
    let now = Date(timeIntervalSince1970: 50_000)
    let snapshot = try ContentFilterRuleSnapshot.redditYouTubeSpike(now: now)

    #expect(snapshot.mode == .blocklist)
    #expect(snapshot.normalizedBlockedDomains == ["reddit.com", "youtube.com"])
    #expect(snapshot.decision(for: "reddit.com", at: now) == .block)
    #expect(snapshot.decision(for: "old.reddit.com", at: now) == .block)
    #expect(snapshot.decision(for: "music.youtube.com", at: now) == .block)
    #expect(snapshot.decision(for: "github.com", at: now) == .allow)
}

@Test
func websiteSpikePolicyProducesFreshRedditYouTubeSnapshot() throws {
    let now = Date(timeIntervalSince1970: 50_500)
    let policy = try FermoSampleData.websiteSpikePolicy(now: now, duration: 300)
    let snapshot = ContentFilterRuleSnapshot(policy: policy, at: now)

    #expect(snapshot.normalizedBlockedDomains == ["reddit.com", "youtube.com"])
    #expect(snapshot.expiresAt == now.addingTimeInterval(300))
    #expect(snapshot.decision(for: "reddit.com", at: now) == .block)
    #expect(snapshot.decision(for: "youtube.com", at: now.addingTimeInterval(299)) == .block)
    #expect(snapshot.decision(for: "youtube.com", at: now.addingTimeInterval(300)) == .allow)
}

@Test
func contentFilterSnapshotExpiresOpen() throws {
    let now = Date(timeIntervalSince1970: 51_000)
    let snapshot = try ContentFilterRuleSnapshot.redditYouTubeSpike(now: now, duration: 60)

    #expect(snapshot.decision(for: "youtube.com", at: now.addingTimeInterval(59)) == .block)
    #expect(snapshot.decision(for: "youtube.com", at: now.addingTimeInterval(60)) == .allow)
}

@Test
func inactiveContentFilterSnapshotAllowsEverythingImmediately() throws {
    let now = Date(timeIntervalSince1970: 51_500)
    let snapshot = ContentFilterRuleSnapshot.inactive(at: now)

    #expect(snapshot.activeSessionIDs.isEmpty)
    #expect(snapshot.normalizedBlockedDomains.isEmpty)
    #expect(snapshot.normalizedAllowedDomains.isEmpty)
    #expect(snapshot.expiresAt == now)
    #expect(snapshot.decision(for: "reddit.com", at: now) == .allow)
    #expect(snapshot.decision(for: "youtube.com", at: now.addingTimeInterval(1)) == .allow)
}

@Test
func focusRoomSnapshotBlocksDomainsOutsideAllowedRoom() throws {
    let now = Date(timeIntervalSince1970: 52_000)
    let contract = FocusContract(
        taskTitle: "Code",
        intendedOutcome: "Validate the filter boundary.",
        mode: .focusRoom,
        rigor: .locked,
        allowedDomains: [try DomainRule("github.com")]
    )
    let session = try FocusSession(
        title: "Code",
        contract: contract,
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-10),
        duration: 600,
        state: .active
    )

    let snapshot = ContentFilterRuleSnapshot(policy: FermoPolicy(sessions: [session]), at: now)

    #expect(snapshot.mode == .focusRoom)
    #expect(snapshot.normalizedAllowedDomains == ["github.com"])
    #expect(snapshot.decision(for: "github.com", at: now) == .allow)
    #expect(snapshot.decision(for: "youtube.com", at: now) == .block)
}

@Test
func contentFilterSnapshotStoreRoundTripsJSON() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("FermoContentFilterRuleSnapshotTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = ContentFilterRuleSnapshotStore(
        fileURL: directory.appendingPathComponent(ContentFilterRuleSnapshot.defaultFileName)
    )
    let snapshot = try ContentFilterRuleSnapshot.redditYouTubeSpike(
        now: Date(timeIntervalSince1970: 53_000),
        duration: 120
    )

    try store.write(snapshot)

    #expect(try store.load() == snapshot)
}
