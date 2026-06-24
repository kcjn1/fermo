import FermoCore
import FermoSystem
import Foundation
import Testing

@Test
func launchRestorePassMaterializesDueWeeklyScheduleAndPreservesPreferences() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = ISO8601DateFormatter().date(from: "2026-01-05T09:45:00Z")!
    let blocklistID = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
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
    let preferences = FermoPreferences(evidenceExportDirectoryPath: "/tmp/Fermo Evidence")
    let store = SpyLaunchStore(loadedSnapshot: FermoSnapshot(
        blocklists: [blocklist],
        schedules: [schedule],
        preferences: preferences
    ))

    let result = try LaunchRestorePass(
        store: store,
        scheduleRestorer: ScheduleRestorer(calendar: calendar)
    ).run(at: now)

    #expect(result.didSaveSnapshot)
    #expect(result.activeSessionsCount == 1)
    #expect(result.snapshot.preferences == preferences)
    #expect(result.snapshot.sessions.first?.state == .active)
    #expect(store.savedSnapshots == [result.snapshot])
}

@Test
func launchRestorePassActivatesDueOneOffScheduledSession() throws {
    let now = Date(timeIntervalSince1970: 600_000)
    let policy = try FocusContractDraft(
        taskTitle: "Write docs",
        intendedOutcome: "Docs published.",
        mode: .blocklist,
        rigor: .locked,
        duration: 3_600,
        blockedDomains: [try DomainRule("youtube.com")]
    )
    .scheduledPolicy(startingAt: now.addingTimeInterval(-300))
    let store = SpyLaunchStore(loadedSnapshot: FermoSnapshot(policy: policy))

    let result = try LaunchRestorePass(store: store).run(at: now)

    #expect(result.didSaveSnapshot)
    #expect(result.activeSessionsCount == 1)
    #expect(result.snapshot.sessions.first?.state == .active)
    #expect(result.snapshot.policy.shouldBlock(host: "youtube.com", at: now))
}

@Test
func launchRestorePassCancelsMissedOneOffScheduledSession() throws {
    let now = Date(timeIntervalSince1970: 610_000)
    let policy = try FocusContractDraft(
        taskTitle: "Write docs",
        intendedOutcome: "Docs published.",
        mode: .blocklist,
        rigor: .locked,
        duration: 1_800,
        blockedDomains: [try DomainRule("youtube.com")]
    )
    .scheduledPolicy(startingAt: now.addingTimeInterval(-3_600))
    let store = SpyLaunchStore(loadedSnapshot: FermoSnapshot(policy: policy))

    let result = try LaunchRestorePass(store: store).run(at: now)

    #expect(result.didSaveSnapshot)
    #expect(result.activeSessionsCount == 0)
    #expect(result.snapshot.sessions.first?.state == .cancelled)
}

@Test
func launchRestorePassDoesNotSaveWhenSnapshotIsAlreadyCurrent() throws {
    let now = Date(timeIntervalSince1970: 620_000)
    let store = SpyLaunchStore()

    let result = try LaunchRestorePass(store: store).run(at: now)

    #expect(!result.didSaveSnapshot)
    #expect(result.activeSessionsCount == 0)
    #expect(store.savedSnapshots.isEmpty)
}

private final class SpyLaunchStore: FermoStore, @unchecked Sendable {
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
