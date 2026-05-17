import Foundation

public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}

public struct WeeklySchedule: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var weekdays: Set<Weekday>
    public var startHour: Int
    public var startMinute: Int
    public var duration: TimeInterval
    public var blocklistIDs: [UUID]
    public var lockedMode: Bool
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        weekdays: Set<Weekday>,
        startHour: Int,
        startMinute: Int,
        duration: TimeInterval,
        blocklistIDs: [UUID],
        lockedMode: Bool = false,
        isEnabled: Bool = true
    ) throws {
        guard !weekdays.isEmpty else { throw FermoValidationError.emptySchedule }
        guard duration > 0 else { throw FermoValidationError.invalidDuration }
        self.id = id
        self.name = name
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.duration = duration
        self.blocklistIDs = blocklistIDs
        self.lockedMode = lockedMode
        self.isEnabled = isEnabled
    }

    public func nextOccurrence(after date: Date, calendar: Calendar = .current) throws -> FocusSession? {
        guard isEnabled else { return nil }
        let startOfSearchDay = calendar.startOfDay(for: date)

        for dayOffset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfSearchDay) else {
                continue
            }
            let weekdayValue = calendar.component(.weekday, from: day)
            guard let weekday = Weekday(rawValue: weekdayValue), weekdays.contains(weekday) else {
                continue
            }
            guard let startsAt = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: day) else {
                continue
            }
            if startsAt > date {
                return try FocusSession(
                    title: name,
                    blocklistIDs: blocklistIDs,
                    startsAt: startsAt,
                    duration: duration,
                    lockedMode: lockedMode,
                    state: .scheduled
                )
            }
        }

        return nil
    }
}
