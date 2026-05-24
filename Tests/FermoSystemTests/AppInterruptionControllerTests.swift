import FermoCore
import FermoSystem
import Foundation
import Testing

@Test
func appInterruptionNormalizesBundleIdentifiers() {
    let identifiers = AppInterruptionController.normalizedBundleIdentifiers([
        " com.apple.calculator ",
        "",
        "   ",
        "com.apple.TextEdit"
    ])

    #expect(identifiers == ["com.apple.calculator", "com.apple.TextEdit"])
}

@Test
func appInterruptionReportTracksMissingAndStrongerHandling() {
    let report = AppInterruptionReport(
        requestedBundleIdentifiers: ["com.apple.calculator", "com.apple.TextEdit"],
        interruptedApps: [
            InterruptedApp(
                bundleIdentifier: "com.apple.calculator",
                displayName: "Calculator",
                processIdentifier: 123,
                terminated: false,
                outcome: .terminateFailed
            )
        ],
        observedAt: Date(timeIntervalSince1970: 40_000)
    )

    #expect(report.matchedBundleIdentifiers == ["com.apple.calculator"])
    #expect(report.missingBundleIdentifiers == ["com.apple.TextEdit"])
    #expect(report.requiresStrongerHandling)
    #expect(!report.neededForceTermination)
    #expect(!report.neededSignalTermination)
    #expect(report.attemptedTerminationCount == 0)
    #expect(report.attemptedSignalTerminationCount == 0)
    #expect(report.attemptedForceTerminationCount == 0)
}

@Test
func appInterruptionReportRecordsForceTerminationFallback() {
    let report = AppInterruptionReport(
        requestedBundleIdentifiers: ["com.apple.calculator"],
        interruptedApps: [
            InterruptedApp(
                bundleIdentifier: "com.apple.calculator",
                displayName: "Calculator",
                processIdentifier: 456,
                terminated: true,
                outcome: .forceTerminateRequested
            )
        ],
        observedAt: Date(timeIntervalSince1970: 40_001)
    )

    #expect(report.neededForceTermination)
    #expect(!report.requiresStrongerHandling)
    #expect(report.attemptedForceTerminationCount == 1)
}

@Test
func appInterruptionReportRecordsSignalTerminationFallback() {
    let report = AppInterruptionReport(
        requestedBundleIdentifiers: ["com.apple.calculator"],
        interruptedApps: [
            InterruptedApp(
                bundleIdentifier: "com.apple.calculator",
                displayName: "Calculator",
                processIdentifier: 789,
                terminated: true,
                outcome: .signalTerminateRequested
            )
        ],
        observedAt: Date(timeIntervalSince1970: 40_002)
    )

    #expect(report.neededSignalTermination)
    #expect(!report.requiresStrongerHandling)
    #expect(report.attemptedSignalTerminationCount == 1)
}

@Test
func appInterruptionPolicyViolationsUseBlocklistTargetsOutsideFocusRoom() throws {
    let now = Date(timeIntervalSince1970: 92_000)
    let policy = try FermoSampleData.appBlockingSpikePolicy(now: now)

    let identifiers = AppInterruptionController.policyViolationBundleIdentifiers(
        policy: policy,
        runningBundleIdentifiers: ["com.apple.calculator", "com.hnc.Discord"],
        at: now,
        currentBundleIdentifier: "com.toolary.fermo"
    )

    #expect(identifiers == ["com.apple.calculator"])
}

@Test
func appInterruptionPolicyViolationsRespectFocusRoomAllowlistAndExclusions() throws {
    let now = Date(timeIntervalSince1970: 92_500)
    let policy = try FocusContractDraft(
        taskTitle: "Code Fermo",
        intendedOutcome: "Wire Focus Room app interruption.",
        mode: .focusRoom,
        rigor: .locked,
        duration: 1_800,
        allowedDomains: [
            try DomainRule("github.com")
        ],
        allowedApps: [
            AppRule(bundleIdentifier: "com.apple.Terminal", displayName: "Terminal")
        ]
    ).activePolicy(startingAt: now)

    let identifiers = AppInterruptionController.policyViolationBundleIdentifiers(
        policy: policy,
        runningBundleIdentifiers: [
            "com.apple.Terminal",
            "com.hnc.Discord",
            "com.apple.finder",
            "com.toolary.fermo"
        ],
        at: now,
        currentBundleIdentifier: "com.toolary.fermo"
    )

    #expect(identifiers == ["com.hnc.Discord"])
}
