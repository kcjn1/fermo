import FermoCore
import Foundation
import Testing

@Test
func weeklyScheduleFindsNextEnabledOccurrence() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let blocklistID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let schedule = try WeeklySchedule(
        name: "Monday Deep Work",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 30,
        duration: 3_600,
        blocklistIDs: [blocklistID],
        lockedMode: true
    )

    let sunday = Date(timeIntervalSince1970: 1_767_548_400) // 2026-01-04 10:20:00 UTC
    let occurrence = try #require(try schedule.nextOccurrence(after: sunday, calendar: calendar))

    #expect(calendar.component(.weekday, from: occurrence.startsAt) == Weekday.monday.rawValue)
    #expect(calendar.component(.hour, from: occurrence.startsAt) == 9)
    #expect(calendar.component(.minute, from: occurrence.startsAt) == 30)
    #expect(occurrence.blocklistIDs == [blocklistID])
    #expect(occurrence.lockedMode)
}

@Test
func disabledWeeklyScheduleDoesNotCreateOccurrence() throws {
    let schedule = try WeeklySchedule(
        name: "Disabled",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 0,
        duration: 1_800,
        blocklistIDs: [],
        isEnabled: false
    )

    #expect(try schedule.nextOccurrence(after: Date()) == nil)
}

@Test
func weeklyScheduleCreatesCurrentActiveOccurrence() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let blocklistID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let schedule = try WeeklySchedule(
        name: "Monday Deep Work",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 30,
        duration: 3_600,
        blocklistIDs: [blocklistID],
        lockedMode: true
    )

    let duringWindow = ISO8601DateFormatter().date(from: "2026-01-05T09:45:00Z")!
    let occurrence = try #require(try schedule.currentOccurrence(at: duringWindow, calendar: calendar))

    #expect(occurrence.title == "Monday Deep Work")
    #expect(occurrence.scheduleID == schedule.id)
    #expect(occurrence.blocklistIDs == [blocklistID])
    #expect(occurrence.state == .active)
    #expect(occurrence.lockedMode)
}

@Test
func weeklyScheduleEditorDraftUpdatesExistingScheduleAndPreservesID() throws {
    let scheduleID = UUID(uuidString: "00000000-0000-0000-0000-0000000000ED")!
    let originalBlocklistID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    let nextBlocklistID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    let original = try WeeklySchedule(
        id: scheduleID,
        name: "Old",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 0,
        duration: 3_600,
        blocklistIDs: [originalBlocklistID],
        lockedMode: true
    )

    var draft = WeeklyScheduleEditorDraft(schedule: original)
    draft.name = "Edited"
    draft.weekdays = [.tuesday, .thursday]
    draft.startHour = 14
    draft.startMinute = 30
    draft.durationMinutes = 45
    draft.blocklistIDs = [nextBlocklistID]
    draft.lockedMode = false

    let edited = try draft.schedule()

    #expect(edited.id == scheduleID)
    #expect(edited.name == "Edited")
    #expect(edited.weekdays == [.tuesday, .thursday])
    #expect(edited.startHour == 14)
    #expect(edited.startMinute == 30)
    #expect(edited.duration == 2_700)
    #expect(edited.blocklistIDs == [nextBlocklistID])
    #expect(!edited.lockedMode)
}

@Test
func weeklyScheduleFocusRoomOccurrenceCarriesContractAndSnapshotsAsFocusRoom() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let schedule = try WeeklySchedule(
        name: "Deep Writing Room",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 30,
        duration: 3_600,
        blocklistIDs: [],
        lockedMode: true,
        mode: .focusRoom,
        allowedDomains: [try DomainRule("developer.apple.com")],
        allowedApps: [AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")]
    )

    let duringWindow = ISO8601DateFormatter().date(from: "2026-01-05T09:45:00Z")!
    let occurrence = try #require(try schedule.currentOccurrence(at: duringWindow, calendar: calendar))

    let contract = try #require(occurrence.contract)
    #expect(contract.isFocusRoom)
    #expect(contract.rigor == .locked)
    #expect(contract.allowedDomains.map(\.normalizedPattern) == ["developer.apple.com"])
    #expect(contract.allowedApps.map(\.bundleIdentifier) == ["com.apple.dt.Xcode"])

    // The materialized session must classify as a Focus Room in the enforcement snapshot.
    let policy = FermoPolicy(sessions: [occurrence])
    let snapshot = ContentFilterRuleSnapshot(policy: policy, at: duringWindow)
    #expect(snapshot.mode == .focusRoom)
    #expect(snapshot.normalizedAllowedDomains == ["developer.apple.com"])
    #expect(snapshot.decision(for: "reddit.com", at: duringWindow) == .block)
    #expect(snapshot.decision(for: "developer.apple.com", at: duringWindow) == .allow)
}

@Test
func weeklyScheduleNextFocusRoomOccurrenceCarriesContract() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let schedule = try WeeklySchedule(
        name: "Room",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 30,
        duration: 3_600,
        blocklistIDs: [],
        lockedMode: false,
        mode: .focusRoom,
        allowedDomains: [try DomainRule("developer.apple.com")]
    )
    let sunday = Date(timeIntervalSince1970: 1_767_548_400)
    let occurrence = try #require(try schedule.nextOccurrence(after: sunday, calendar: calendar))
    #expect(occurrence.contract?.isFocusRoom == true)
    #expect(occurrence.contract?.rigor == .soft)
}

@Test
func weeklyScheduleBlocklistOccurrenceHasNoContract() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let schedule = try WeeklySchedule(
        name: "Blocklist",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 30,
        duration: 3_600,
        blocklistIDs: [UUID()],
        lockedMode: true
    )
    let duringWindow = ISO8601DateFormatter().date(from: "2026-01-05T09:45:00Z")!
    let occurrence = try #require(try schedule.currentOccurrence(at: duringWindow, calendar: calendar))
    #expect(occurrence.contract == nil)
}

@Test
func weeklyScheduleCodableRoundTripsFocusRoomFields() throws {
    let schedule = try WeeklySchedule(
        name: "Room",
        weekdays: [.monday, .wednesday],
        startHour: 8,
        startMinute: 0,
        duration: 5_400,
        blocklistIDs: [],
        lockedMode: true,
        mode: .focusRoom,
        allowedDomains: [try DomainRule("developer.apple.com")],
        allowedApps: [AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")]
    )
    let data = try JSONEncoder().encode(schedule)
    let decoded = try JSONDecoder().decode(WeeklySchedule.self, from: data)
    #expect(decoded == schedule)
    #expect(decoded.mode == .focusRoom)
    #expect(decoded.allowedDomains.map(\.normalizedPattern) == ["developer.apple.com"])
}

@Test
func weeklyScheduleDecodesLegacySnapshotWithoutModeAsBlocklist() throws {
    // A snapshot written before Focus Room schedules existed has no mode/allowed* keys.
    let legacyJSON = """
    {
      "id": "00000000-0000-0000-0000-0000000000AA",
      "name": "Legacy",
      "weekdays": [2],
      "startHour": 9,
      "startMinute": 0,
      "duration": 3600,
      "blocklistIDs": ["00000000-0000-0000-0000-0000000000BB"],
      "lockedMode": true,
      "isEnabled": true
    }
    """
    let decoded = try JSONDecoder().decode(WeeklySchedule.self, from: Data(legacyJSON.utf8))
    #expect(decoded.mode == .blocklist)
    #expect(decoded.allowedDomains.isEmpty)
    #expect(decoded.allowedApps.isEmpty)
    #expect(decoded.name == "Legacy")
}

@Test
func scheduleRestorerMaterializesFocusRoomScheduleAsActiveFocusRoomSession() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let schedule = try WeeklySchedule(
        name: "Writing Room",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 30,
        duration: 3_600,
        blocklistIDs: [],
        lockedMode: true,
        mode: .focusRoom,
        allowedDomains: [try DomainRule("developer.apple.com")]
    )
    let snapshot = FermoSnapshot(blocklists: [], schedules: [schedule])
    let now = ISO8601DateFormatter().date(from: "2026-01-05T09:45:00Z")!

    let restored = try ScheduleRestorer(calendar: calendar).restoringDueSessions(in: snapshot, at: now)
    #expect(restored.didChange)
    let active = restored.snapshot.policy.activeSessions(at: now)
    #expect(active.count == 1)
    #expect(active.first?.contract?.isFocusRoom == true)
    #expect(ContentFilterRuleSnapshot(policy: restored.snapshot.policy, at: now).mode == .focusRoom)
}

@Test
func scheduleRestorerMaterializesDueScheduleOnce() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let blocklistID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
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
    let snapshot = FermoSnapshot(blocklists: [blocklist], schedules: [schedule])
    let now = ISO8601DateFormatter().date(from: "2026-01-05T09:45:00Z")!

    let firstPass = try ScheduleRestorer(calendar: calendar).restoringDueSessions(in: snapshot, at: now)
    let secondPass = try ScheduleRestorer(calendar: calendar).restoringDueSessions(in: firstPass.snapshot, at: now)

    #expect(firstPass.didChange)
    #expect(!secondPass.didChange)
    #expect(secondPass.snapshot.schedules == [schedule])
    #expect(secondPass.snapshot.sessions.count == 1)
    #expect(secondPass.snapshot.sessions.first?.scheduleID == schedule.id)
    #expect(secondPass.snapshot.policy.activeSessions(at: now).count == 1)
}
