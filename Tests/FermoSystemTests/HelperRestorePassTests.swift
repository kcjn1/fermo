import FermoCore
import FermoSystem
import Foundation
import Testing

@Test
func helperRestorePassMaterializesDueSessionAndWritesRuleSnapshot() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = ISO8601DateFormatter().date(from: "2026-01-05T09:45:00Z")!
    let blocklistID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    let blocklist = Blocklist(id: blocklistID, name: "Writing", domainRules: [try DomainRule("reddit.com")])
    let schedule = try WeeklySchedule(
        name: "Writing",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 30,
        duration: 3_600,
        blocklistIDs: [blocklistID],
        lockedMode: true
    )
    let store = SpyFermoStore(loadedSnapshot: FermoSnapshot(blocklists: [blocklist], schedules: [schedule]))
    let ruleSnapshotStore = SpyRuleSnapshotStore()
    var state = HelperRestorePassState()

    let result = try HelperRestorePass(
        store: store,
        ruleSnapshotStore: ruleSnapshotStore,
        scheduleRestorer: ScheduleRestorer(calendar: calendar)
    ).run(at: now, state: &state)

    #expect(result.didSaveSnapshot)
    #expect(result.didWriteRuleSnapshot)
    #expect(result.activeSessionsCount == 1)
    #expect(store.savedSnapshots.count == 1)
    #expect(store.savedSnapshots.last?.sessions.count == 1)
    #expect(ruleSnapshotStore.writtenSnapshots.last?.normalizedBlockedDomains == ["reddit.com"])
}

@Test
func helperRestorePassRefreshesRuleSnapshotWhenActiveRulesChangeForSameSession() throws {
    let now = Date(timeIntervalSince1970: 300_000)
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!
    let blocklistID = UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!
    let initialSnapshot = ContentFilterRuleSnapshot(
        generatedAt: now.addingTimeInterval(-10),
        activeSessionIDs: [sessionID],
        mode: .blocklist,
        blockedDomains: [try DomainRule("reddit.com")],
        expiresAt: now.addingTimeInterval(3_600)
    )
    let blocklist = Blocklist(
        id: blocklistID,
        name: "Updated",
        domainRules: [try DomainRule("reddit.com"), try DomainRule("youtube.com")]
    )
    let session = try FocusSession(
        id: sessionID,
        title: "Updated active rules",
        blocklistIDs: [blocklistID],
        startsAt: now.addingTimeInterval(-60),
        duration: 3_600,
        state: .active
    )
    let store = SpyFermoStore(loadedSnapshot: FermoSnapshot(blocklists: [blocklist], sessions: [session]))
    let ruleSnapshotStore = SpyRuleSnapshotStore()
    var state = HelperRestorePassState(
        didSeeActiveSession: true,
        didRunEmptyCleanup: false,
        lastRuleSnapshot: initialSnapshot
    )

    let result = try HelperRestorePass(store: store, ruleSnapshotStore: ruleSnapshotStore)
        .run(at: now, state: &state)

    #expect(!result.didSaveSnapshot)
    #expect(result.didWriteRuleSnapshot)
    #expect(ruleSnapshotStore.writtenSnapshots.count == 1)
    #expect(ruleSnapshotStore.writtenSnapshots.last?.activeSessionIDs == [sessionID])
    #expect(ruleSnapshotStore.writtenSnapshots.last?.normalizedBlockedDomains == ["reddit.com", "youtube.com"])
}

@Test
func helperRestorePassDoesNotRewriteRuleSnapshotWhenOnlyGeneratedAtChanges() throws {
    let previousGeneratedAt = Date(timeIntervalSince1970: 319_990)
    let now = Date(timeIntervalSince1970: 320_000)
    let sessionID = UUID(uuidString: "00000000-0000-0000-0000-00000000A004")!
    let blocklistID = UUID(uuidString: "00000000-0000-0000-0000-00000000A005")!
    let blocklist = Blocklist(id: blocklistID, name: "Writing", domainRules: [try DomainRule("reddit.com")])
    let session = try FocusSession(
        id: sessionID,
        title: "Same active rules",
        blocklistIDs: [blocklistID],
        startsAt: now.addingTimeInterval(-60),
        duration: 3_600,
        state: .active
    )
    let previousSnapshot = ContentFilterRuleSnapshot(
        generatedAt: previousGeneratedAt,
        activeSessionIDs: [sessionID],
        mode: .blocklist,
        blockedDomains: [try DomainRule("reddit.com")],
        expiresAt: session.endsAt
    )
    let store = SpyFermoStore(loadedSnapshot: FermoSnapshot(blocklists: [blocklist], sessions: [session]))
    let ruleSnapshotStore = SpyRuleSnapshotStore()
    var state = HelperRestorePassState(
        didSeeActiveSession: true,
        didRunEmptyCleanup: false,
        lastRuleSnapshot: previousSnapshot
    )

    let result = try HelperRestorePass(store: store, ruleSnapshotStore: ruleSnapshotStore)
        .run(at: now, state: &state)

    #expect(!result.didWriteRuleSnapshot)
    #expect(ruleSnapshotStore.writtenSnapshots.isEmpty)
    #expect(state.lastRuleSnapshot?.generatedAt == previousGeneratedAt)
}

@Test
func helperRestorePassClearsRuleSnapshotAfterSessionsExpire() throws {
    let now = Date(timeIntervalSince1970: 310_000)
    let store = SpyFermoStore()
    let ruleSnapshotStore = SpyRuleSnapshotStore()
    var state = HelperRestorePassState(
        didSeeActiveSession: true,
        didRunEmptyCleanup: false,
        lastRuleSnapshot: try ContentFilterRuleSnapshot.redditYouTubeSpike(now: now.addingTimeInterval(-60), duration: 600)
    )

    let result = try HelperRestorePass(store: store, ruleSnapshotStore: ruleSnapshotStore)
        .run(at: now, state: &state)

    #expect(result.didClearRuleSnapshot)
    #expect(result.activeSessionsCount == 0)
    #expect(ruleSnapshotStore.writtenSnapshots.last?.expiresAt == now)
    #expect(state.didRunEmptyCleanup)
    #expect(state.lastRuleSnapshot?.activeSessionIDs == [])
}

private final class SpyFermoStore: FermoStore, @unchecked Sendable {
    var loadedSnapshot: FermoSnapshot
    var savedSnapshots: [FermoSnapshot] = []

    init(loadedSnapshot: FermoSnapshot = FermoSnapshot()) {
        self.loadedSnapshot = loadedSnapshot
    }

    func load() throws -> FermoSnapshot {
        loadedSnapshot
    }

    func save(_ snapshot: FermoSnapshot) throws {
        savedSnapshots.append(snapshot)
        loadedSnapshot = snapshot
    }
}

private final class SpyRuleSnapshotStore: ContentFilterRuleSnapshotWriting, @unchecked Sendable {
    var writtenSnapshots: [ContentFilterRuleSnapshot] = []

    func write(_ snapshot: ContentFilterRuleSnapshot) throws {
        writtenSnapshots.append(snapshot)
    }
}
