import FermoSystem
import Testing

@Test
func systemExtensionApprovalStatusProvidesUserFacingMessages() {
    #expect(SystemExtensionApprovalStatus.notRequested.displayName == "not requested")
    #expect(SystemExtensionApprovalStatus.requested.displayName == "request submitted")
    #expect(SystemExtensionApprovalStatus.needsUserApproval.displayName == "needs approval")
    #expect(SystemExtensionApprovalStatus.requiresReboot.displayName == "requires reboot")
    #expect(SystemExtensionApprovalStatus.ready.displayName == "ready")
    #expect(SystemExtensionApprovalStatus.failed("missing entitlement").displayName == "failed")

    #expect(SystemExtensionApprovalStatus.ready.tone == .ok)
    #expect(SystemExtensionApprovalStatus.notRequested.tone == .warning)
    #expect(SystemExtensionApprovalStatus.failed("missing entitlement").tone == .warning)

    #expect(SystemExtensionApprovalStatus.ready.startSummary == "App Guard approval is ready.")
    #expect(SystemExtensionApprovalStatus.needsUserApproval.startSummary == "Approve App Guard in System Settings to enable app launch blocking.")
    #expect(SystemExtensionApprovalStatus.failed("missing entitlement").startSummary == "App Guard approval failed: missing entitlement")
}
