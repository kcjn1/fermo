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
    /// Recurring sessions default to Blocklist mode. When set to `.focusRoom`, each
    /// materialized occurrence carries a Focus Room `FocusContract` built from the
    /// `allowedDomains`/`allowedApps` below, so scheduled and ad-hoc Focus Room sessions
    /// enforce identically.
    public var mode: FocusMode
    public var allowedDomains: [DomainRule]
    public var allowedApps: [AppRule]

    public init(
        id: UUID = UUID(),
        name: String,
        weekdays: Set<Weekday>,
        startHour: Int,
        startMinute: Int,
        duration: TimeInterval,
        blocklistIDs: [UUID],
        lockedMode: Bool = false,
        isEnabled: Bool = true,
        mode: FocusMode = .blocklist,
        allowedDomains: [DomainRule] = [],
        allowedApps: [AppRule] = []
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
        self.mode = mode
        self.allowedDomains = allowedDomains
        self.allowedApps = allowedApps
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, weekdays, startHour, startMinute, duration
        case blocklistIDs, lockedMode, isEnabled
        case mode, allowedDomains, allowedApps
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // decodeIfPresent + defaults so snapshots written before Focus Room schedules still load.
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.weekdays = try container.decode(Set<Weekday>.self, forKey: .weekdays)
        self.startHour = try container.decode(Int.self, forKey: .startHour)
        self.startMinute = try container.decode(Int.self, forKey: .startMinute)
        self.duration = try container.decode(TimeInterval.self, forKey: .duration)
        self.blocklistIDs = try container.decodeIfPresent([UUID].self, forKey: .blocklistIDs) ?? []
        self.lockedMode = try container.decodeIfPresent(Bool.self, forKey: .lockedMode) ?? false
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.mode = try container.decodeIfPresent(FocusMode.self, forKey: .mode) ?? .blocklist
        self.allowedDomains = try container.decodeIfPresent([DomainRule].self, forKey: .allowedDomains) ?? []
        self.allowedApps = try container.decodeIfPresent([AppRule].self, forKey: .allowedApps) ?? []
    }

    /// The Focus Room contract a materialized occurrence should carry, or `nil` for Blocklist mode.
    private func materializedContract() -> FocusContract? {
        guard mode == .focusRoom else { return nil }
        return FocusContract(
            taskTitle: name,
            intendedOutcome: name,
            mode: .focusRoom,
            rigor: lockedMode ? .locked : .soft,
            allowedDomains: allowedDomains,
            allowedApps: allowedApps
        )
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
                    contract: materializedContract(),
                    scheduleID: id,
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

    public func currentOccurrence(at date: Date, calendar: Calendar = .current) throws -> FocusSession? {
        guard isEnabled else { return nil }
        let startOfDay = calendar.startOfDay(for: date)
        let weekdayValue = calendar.component(.weekday, from: startOfDay)
        guard let weekday = Weekday(rawValue: weekdayValue), weekdays.contains(weekday) else {
            return nil
        }
        guard let startsAt = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: startOfDay) else {
            return nil
        }
        let endsAt = startsAt.addingTimeInterval(duration)
        guard startsAt <= date && date < endsAt else {
            return nil
        }

        return try FocusSession(
            title: name,
            contract: materializedContract(),
            scheduleID: id,
            blocklistIDs: blocklistIDs,
            startsAt: startsAt,
            endsAt: endsAt,
            lockedMode: lockedMode,
            state: .active
        )
    }
}

public struct WeeklyScheduleEditorDraft: Equatable, Sendable {
    public var id: UUID?
    public var name: String
    public var weekdays: Set<Weekday>
    public var startHour: Int
    public var startMinute: Int
    public var durationMinutes: Int
    public var blocklistIDs: [UUID]
    public var lockedMode: Bool
    public var isEnabled: Bool
    public var mode: FocusMode
    public var allowedDomains: [DomainRule]
    public var allowedApps: [AppRule]

    public init(
        id: UUID? = nil,
        name: String = "",
        weekdays: Set<Weekday> = [],
        startHour: Int = 9,
        startMinute: Int = 0,
        durationMinutes: Int = 90,
        blocklistIDs: [UUID] = [],
        lockedMode: Bool = true,
        isEnabled: Bool = true,
        mode: FocusMode = .blocklist,
        allowedDomains: [DomainRule] = [],
        allowedApps: [AppRule] = []
    ) {
        self.id = id
        self.name = name
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
        self.blocklistIDs = blocklistIDs
        self.lockedMode = lockedMode
        self.isEnabled = isEnabled
        self.mode = mode
        self.allowedDomains = allowedDomains
        self.allowedApps = allowedApps
    }

    public init(schedule: WeeklySchedule) {
        self.init(
            id: schedule.id,
            name: schedule.name,
            weekdays: schedule.weekdays,
            startHour: schedule.startHour,
            startMinute: schedule.startMinute,
            durationMinutes: Int(schedule.duration / 60),
            blocklistIDs: schedule.blocklistIDs,
            lockedMode: schedule.lockedMode,
            isEnabled: schedule.isEnabled,
            mode: schedule.mode,
            allowedDomains: schedule.allowedDomains,
            allowedApps: schedule.allowedApps
        )
    }

    public func schedule() throws -> WeeklySchedule {
        try WeeklySchedule(
            id: id ?? UUID(),
            name: name,
            weekdays: weekdays,
            startHour: startHour,
            startMinute: startMinute,
            duration: TimeInterval(durationMinutes * 60),
            blocklistIDs: blocklistIDs,
            lockedMode: lockedMode,
            isEnabled: isEnabled,
            mode: mode,
            allowedDomains: allowedDomains,
            allowedApps: allowedApps
        )
    }
}
