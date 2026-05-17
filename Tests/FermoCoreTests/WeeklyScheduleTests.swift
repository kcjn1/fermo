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
