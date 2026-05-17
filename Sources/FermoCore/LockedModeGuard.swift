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
        if session.lockedMode && session.isActive(at: date) {
            throw LockedModeError.activeSessionLocked(until: session.endsAt)
        }
    }
}
