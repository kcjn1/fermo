import FermoCore
import Foundation
import Testing

@Test
func focusSessionComputesDurationAndActiveWindow() throws {
    let start = Date(timeIntervalSince1970: 1_800)
    let session = try FocusSession(
        title: "Deep Work",
        blocklistIDs: [],
        startsAt: start,
        duration: 3_600,
        lockedMode: true,
        state: .active
    )

    #expect(session.duration == 3_600)
    #expect(session.isActive(at: start.addingTimeInterval(1)))
    #expect(!session.isActive(at: start.addingTimeInterval(3_600)))
}

@Test
func invalidSessionDurationIsRejected() {
    #expect(throws: FermoValidationError.invalidDuration) {
        _ = try FocusSession(
            title: "Bad",
            blocklistIDs: [],
            startsAt: Date(),
            duration: 0
        )
    }
}
