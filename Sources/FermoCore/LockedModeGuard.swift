import Foundation

public enum LockedModeMutation: String, Sendable {
    case endSession
    case shortenSession
    case editSessionBlocklists
    case deleteProtectedBlocklist
}

public enum LockedModeError: Error, Equatable, Sendable {
    case activeSessionLocked(until: Date)
}

public struct LockedModeGuard: Sendable {
    public init() {}

    public func validate(_ mutation: LockedModeMutation, for session: FocusSession, at date: Date) throws {
        _ = mutation
        if session.isActive(at: date) && (session.lockedMode || session.rigor == .locked || session.rigor == .emergency) {
            throw LockedModeError.activeSessionLocked(until: session.endsAt)
        }
    }
}
