import Foundation

public struct ScheduleRestoreResult: Equatable, Sendable {
    public var snapshot: FermoSnapshot
    public var didChange: Bool

    public init(snapshot: FermoSnapshot, didChange: Bool) {
        self.snapshot = snapshot
        self.didChange = didChange
    }
}

public struct ScheduleRestorer: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func restoringDueSessions(
        in snapshot: FermoSnapshot,
        at date: Date = Date()
    ) throws -> ScheduleRestoreResult {
        var nextSnapshot = snapshot
        var didChange = false

        for schedule in snapshot.schedules {
            guard let occurrence = try schedule.currentOccurrence(at: date, calendar: calendar) else {
                continue
            }

            if nextSnapshot.sessions.contains(where: { session in
                session.scheduleID == schedule.id && session.startsAt == occurrence.startsAt
            }) {
                continue
            }

            nextSnapshot.sessions.append(occurrence)
            didChange = true
        }

        return ScheduleRestoreResult(snapshot: nextSnapshot, didChange: didChange)
    }
}
