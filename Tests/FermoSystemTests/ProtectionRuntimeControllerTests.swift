import FermoCore
import FermoSystem
import Foundation
import Testing

@Test
func runtimeStopWebsiteSpikeClearsStoreAndDeactivatesFilter() async throws {
    let now = Date(timeIntervalSince1970: 50_000)
    let store = SpyFermoStore()
    let websiteBlockingController = SpyWebsiteBlockingController()
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: websiteBlockingController
    )
    let policy = try FermoSampleData.websiteSpikePolicy(now: now)

    let result = try await controller.stopDiagnosticProtection(
        kind: .websiteSpike,
        currentPolicy: policy,
        at: now
    )

    #expect(result.policy == FermoPolicy())
    #expect(result.didClearPersistedPolicy)
    #expect(result.didDeactivateWebsiteBlocking)
    #expect(store.savedSnapshots == [FermoSnapshot()])
    #expect(websiteBlockingController.deactivateCallCount == 1)
}

@Test
func runtimeDiagnosticTeardownPreservesSchedulesAndPreferences() async throws {
    let now = Date(timeIntervalSince1970: 50_250)
    let schedule = try WeeklySchedule(
        name: "Morning",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 0,
        duration: 3_600,
        blocklistIDs: []
    )
    let preferences = FermoPreferences(evidenceExportDirectoryPath: "/tmp/Fermo Evidence")
    let store = SpyFermoStore(loadedSnapshot: FermoSnapshot(
        schedules: [schedule],
        preferences: preferences
    ))
    let websiteBlockingController = SpyWebsiteBlockingController()
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: websiteBlockingController
    )
    let policy = try FermoSampleData.websiteSpikePolicy(now: now)

    _ = try await controller.stopDiagnosticProtection(
        kind: .websiteSpike,
        currentPolicy: policy,
        at: now
    )

    #expect(store.savedSnapshots == [FermoSnapshot(
        policy: FermoPolicy(),
        schedules: [schedule],
        preferences: preferences
    )])
}

@Test
func runtimeStopWebsiteSpikeDoesNotClearStoreWhenFilterDeactivationFails() async throws {
    let now = Date(timeIntervalSince1970: 50_500)
    let store = SpyFermoStore()
    let websiteBlockingController = SpyWebsiteBlockingController()
    websiteBlockingController.deactivateError = SpyWebsiteBlockingError.failed
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: websiteBlockingController
    )
    let policy = try FermoSampleData.websiteSpikePolicy(now: now)

    await #expect(throws: SpyWebsiteBlockingError.failed) {
        _ = try await controller.stopDiagnosticProtection(
            kind: .websiteSpike,
            currentPolicy: policy,
            at: now
        )
    }
    #expect(store.savedSnapshots.isEmpty)
    #expect(websiteBlockingController.deactivateCallCount == 1)
}

@Test
func runtimeStopAppSpikeClearsStoreWithoutDeactivatingFilter() async throws {
    let now = Date(timeIntervalSince1970: 51_000)
    let store = SpyFermoStore()
    let websiteBlockingController = SpyWebsiteBlockingController()
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: websiteBlockingController
    )
    let policy = try FermoSampleData.appBlockingSpikePolicy(now: now)

    let result = try await controller.stopDiagnosticProtection(
        kind: .appSpike,
        currentPolicy: policy,
        at: now
    )

    #expect(result.policy == FermoPolicy())
    #expect(result.didClearPersistedPolicy)
    #expect(!result.didDeactivateWebsiteBlocking)
    #expect(store.savedSnapshots == [FermoSnapshot()])
    #expect(websiteBlockingController.deactivateCallCount == 0)
}

@Test
func runtimeClearAllDiagnosticsClearsStoreAndDeactivatesFilter() async throws {
    let now = Date(timeIntervalSince1970: 51_500)
    let store = SpyFermoStore()
    let websiteBlockingController = SpyWebsiteBlockingController()
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: websiteBlockingController
    )
    let policy = try FermoSampleData.helperPersistenceSpikePolicy(now: now)

    let result = try await controller.stopDiagnosticProtection(
        kind: .allDiagnostics,
        currentPolicy: policy,
        at: now
    )

    #expect(result.policy == FermoPolicy())
    #expect(result.didClearPersistedPolicy)
    #expect(result.didDeactivateWebsiteBlocking)
    #expect(store.savedSnapshots == [FermoSnapshot()])
    #expect(websiteBlockingController.deactivateCallCount == 1)
}

@Test
func runtimeClearAllDiagnosticsRejectsSoftRealContractBeforeCleanup() async throws {
    let now = Date(timeIntervalSince1970: 51_750)
    let store = SpyFermoStore()
    let websiteBlockingController = SpyWebsiteBlockingController()
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: websiteBlockingController
    )
    let policy = try FocusContractDraft(
        taskTitle: "Write beta notes",
        intendedOutcome: "Finish a real user-facing contract.",
        mode: .blocklist,
        rigor: .soft,
        duration: 1_800,
        blockedDomains: [try DomainRule("reddit.com")]
    ).activePolicy(startingAt: now)

    await #expect(throws: SystemIntegrationError.diagnosticTeardownRejected("Write beta notes")) {
        _ = try await controller.stopDiagnosticProtection(
            kind: .allDiagnostics,
            currentPolicy: policy,
            at: now
        )
    }
    #expect(store.savedSnapshots.isEmpty)
    #expect(websiteBlockingController.deactivateCallCount == 0)
}

@Test
func runtimeStopHelperSpikeRejectsActiveLockedContractBeforeCleanup() async throws {
    let now = Date(timeIntervalSince1970: 52_000)
    let store = SpyFermoStore()
    let websiteBlockingController = SpyWebsiteBlockingController()
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: websiteBlockingController
    )
    let policy = try FocusContractDraft(
        taskTitle: "Ship Fermo",
        intendedOutcome: "Validate the protected runtime.",
        mode: .blocklist,
        rigor: .locked,
        duration: 1_800,
        blockedDomains: [try DomainRule("reddit.com")]
    ).activePolicy(startingAt: now)

    await #expect(throws: SystemIntegrationError.diagnosticTeardownRejected("Ship Fermo")) {
        _ = try await controller.stopDiagnosticProtection(
            kind: .helperSpike,
            currentPolicy: policy,
            at: now
        )
    }
    #expect(store.savedSnapshots.isEmpty)
    #expect(websiteBlockingController.deactivateCallCount == 0)
}

@Test
func runtimeTerminalPolicyDeactivatesWebsiteBlockingOnlyWhenNoSessionsRemainActive() async throws {
    let now = Date(timeIntervalSince1970: 53_000)
    let websiteBlockingController = SpyWebsiteBlockingController()
    let controller = ProtectionRuntimeController(websiteBlockingController: websiteBlockingController)
    let terminalPolicy = FermoPolicy()

    let result = try await controller.deactivateWebsiteBlockingAfterTerminalPolicy(
        terminalPolicy,
        at: now
    )

    #expect(result.policy == terminalPolicy)
    #expect(!result.didClearPersistedPolicy)
    #expect(result.didDeactivateWebsiteBlocking)
    #expect(websiteBlockingController.deactivateCallCount == 1)
}

@Test
func runtimeTerminalPolicyLeavesWebsiteBlockingActiveWhenSessionStillActive() async throws {
    let now = Date(timeIntervalSince1970: 54_000)
    let websiteBlockingController = SpyWebsiteBlockingController()
    let controller = ProtectionRuntimeController(websiteBlockingController: websiteBlockingController)
    let activePolicy = try FermoSampleData.websiteSpikePolicy(now: now)

    let result = try await controller.deactivateWebsiteBlockingAfterTerminalPolicy(
        activePolicy,
        at: now
    )

    #expect(result.policy == activePolicy)
    #expect(!result.didClearPersistedPolicy)
    #expect(!result.didDeactivateWebsiteBlocking)
    #expect(websiteBlockingController.deactivateCallCount == 0)
}

@Test
func runtimePersistsPolicyWhenStoreIsConfigured() throws {
    let now = Date(timeIntervalSince1970: 55_000)
    let store = SpyFermoStore()
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: SpyWebsiteBlockingController()
    )
    let policy = try FermoSampleData.websiteSpikePolicy(now: now)

    let didPersist = try controller.persistPolicy(policy)

    #expect(didPersist)
    #expect(store.savedSnapshots == [FermoSnapshot(policy: policy)])
}

@Test
func runtimePersistsPolicyWithoutDroppingSchedules() throws {
    let now = Date(timeIntervalSince1970: 55_500)
    let schedule = try WeeklySchedule(
        name: "Morning",
        weekdays: [.monday],
        startHour: 9,
        startMinute: 0,
        duration: 3_600,
        blocklistIDs: []
    )
    let store = SpyFermoStore(loadedSnapshot: FermoSnapshot(schedules: [schedule]))
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: SpyWebsiteBlockingController()
    )
    let policy = try FermoSampleData.websiteSpikePolicy(now: now)

    let didPersist = try controller.persistPolicy(policy)

    #expect(didPersist)
    #expect(store.savedSnapshots == [FermoSnapshot(policy: policy, schedules: [schedule])])
}

@Test
func runtimePersistsPolicyWithoutDroppingPreferences() throws {
    let now = Date(timeIntervalSince1970: 55_700)
    let preferences = FermoPreferences(evidenceExportDirectoryPath: "/tmp/Fermo Evidence")
    let store = SpyFermoStore(loadedSnapshot: FermoSnapshot(preferences: preferences))
    let controller = ProtectionRuntimeController(
        store: store,
        websiteBlockingController: SpyWebsiteBlockingController()
    )
    let policy = try FermoSampleData.websiteSpikePolicy(now: now)

    let didPersist = try controller.persistPolicy(policy)

    #expect(didPersist)
    #expect(store.savedSnapshots == [FermoSnapshot(policy: policy, preferences: preferences)])
}

@Test
func runtimeRequiredPersistenceReportsMissingAppGroup() throws {
    let controller = ProtectionRuntimeController(
        websiteBlockingController: SpyWebsiteBlockingController()
    )

    #expect(throws: SystemIntegrationError.missingAppGroupContainer("unconfigured")) {
        try controller.persistPolicyRequired(FermoPolicy())
    }
}

private final class SpyFermoStore: FermoStore, @unchecked Sendable {
    var loadedSnapshot: FermoSnapshot
    var savedSnapshots: [FermoSnapshot] = []

    init(loadedSnapshot: FermoSnapshot = FermoSnapshot()) {
        self.loadedSnapshot = loadedSnapshot
    }

    func load() throws -> FermoSnapshot {
        loadedSnapshot
    }

    func save(_ snapshot: FermoSnapshot) throws {
        savedSnapshots.append(snapshot)
    }
}

private final class SpyWebsiteBlockingController: WebsiteBlockingControlling, @unchecked Sendable {
    var deactivateCallCount = 0
    var deactivateError: (any Error)?

    func status() async -> WebsiteBlockingStatus {
        .ready
    }

    func activate(policy: FermoPolicy) async throws {
        _ = policy
    }

    func deactivate() async throws {
        deactivateCallCount += 1
        if let deactivateError {
            throw deactivateError
        }
    }
}

private enum SpyWebsiteBlockingError: Error, Equatable {
    case failed
}
