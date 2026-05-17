import FermoCore
import Foundation
import Testing

@Test
func lockedModeBlocksEarlyEndForActiveSession() throws {
    let now = Date(timeIntervalSince1970: 10_000)
    let session = try FocusSession(
        title: "Locked",
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-60),
        duration: 600,
        lockedMode: true,
        state: .active
    )

    #expect(throws: LockedModeError.activeSessionLocked(until: session.endsAt)) {
        try LockedModeGuard().validate(.endSession, for: session, at: now)
    }
}

@Test
func lockedModeAllowsChangesAfterSessionEnds() throws {
    let now = Date(timeIntervalSince1970: 10_000)
    let session = try FocusSession(
        title: "Ended",
        blocklistIDs: [],
        startsAt: now.addingTimeInterval(-600),
        duration: 300,
        lockedMode: true,
        state: .active
    )

    try LockedModeGuard().validate(.endSession, for: session, at: now)
}
