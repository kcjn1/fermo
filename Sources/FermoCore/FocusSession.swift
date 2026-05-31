import Foundation

public enum FocusSessionState: String, Codable, Sendable {
    case scheduled
    case active
    case completed
    case cancelled
}

public struct FocusSession: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var contract: FocusContract?
    public var scheduleID: UUID?
    public var blocklistIDs: [UUID]
    public var startsAt: Date
    public var endsAt: Date
    public var lockedMode: Bool
    public var rigor: ContractRigor
    public var state: FocusSessionState

    public init(
        id: UUID = UUID(),
        title: String,
        contract: FocusContract? = nil,
        scheduleID: UUID? = nil,
        blocklistIDs: [UUID],
        startsAt: Date,
        endsAt: Date,
        lockedMode: Bool = false,
        rigor: ContractRigor? = nil,
        state: FocusSessionState = .scheduled
    ) throws {
        guard endsAt > startsAt else { throw FermoValidationError.invalidDuration }
        self.id = id
        self.title = title
        self.contract = contract
        self.scheduleID = scheduleID
        self.blocklistIDs = blocklistIDs
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.lockedMode = lockedMode
        self.rigor = rigor ?? contract?.rigor ?? (lockedMode ? .locked : .soft)
        self.state = state
    }

    public init(
        id: UUID = UUID(),
        title: String,
        contract: FocusContract? = nil,
        scheduleID: UUID? = nil,
        blocklistIDs: [UUID],
        startsAt: Date,
        duration: TimeInterval,
        lockedMode: Bool = false,
        rigor: ContractRigor? = nil,
        state: FocusSessionState = .scheduled
    ) throws {
        guard duration > 0 else { throw FermoValidationError.invalidDuration }
        try self.init(
            id: id,
            title: title,
            contract: contract,
            scheduleID: scheduleID,
            blocklistIDs: blocklistIDs,
            startsAt: startsAt,
            endsAt: startsAt.addingTimeInterval(duration),
            lockedMode: lockedMode,
            rigor: rigor,
            state: state
        )
    }

    public var duration: TimeInterval {
        endsAt.timeIntervalSince(startsAt)
    }

    public func isActive(at date: Date) -> Bool {
        state == .active && startsAt <= date && date < endsAt
    }

    public func activated() -> FocusSession {
        var copy = self
        copy.state = .active
        return copy
    }

    public func completed() -> FocusSession {
        var copy = self
        copy.state = .completed
        return copy
    }
}
