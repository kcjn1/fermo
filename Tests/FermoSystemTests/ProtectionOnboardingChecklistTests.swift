import FermoSystem
import Testing

@Test
func protectionOnboardingChecklistShowsApprovalActionsBeforeRuntimeIsReady() {
    let checklist = ProtectionOnboardingChecklist(
        websiteBlockingStatus: .needsPermission,
        appGuardApprovalStatus: .needsUserApproval,
        helperStatus: .requiresApproval
    )

    #expect(checklist.overallState == .actionNeeded)
    #expect(checklist.items.map(\.title) == [
        "Website blocking approval",
        "App launch approval",
        "Login item helper"
    ])
    #expect(checklist.items.map(\.state) == [
        .actionNeeded,
        .actionNeeded,
        .actionNeeded
    ])
    #expect(checklist.items[0].detail == "Approve the Fermo Focus Filter before website rules can be enforced.")
    #expect(checklist.items[1].detail == "Approve App Guard in System Settings before protected sessions can deny app relaunches.")
    #expect(checklist.items[2].detail == "Allow the login item so active sessions can be restored after relaunch or login.")
}

@Test
func protectionOnboardingChecklistReportsReadyWhenAllRuntimeGatesAreReady() {
    let checklist = ProtectionOnboardingChecklist(
        websiteBlockingStatus: .active,
        appGuardApprovalStatus: .ready,
        helperStatus: .enabled
    )

    #expect(checklist.overallState == .ready)
    #expect(checklist.items.allSatisfy { $0.state == .ready })
    #expect(checklist.summary == "Runtime approvals are ready for a signed validation pass.")
}

