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

    await #expect(throws: LockedModeError.activeSessionLocked(until: now.addingTimeInterval(1_800))) {
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
func runtimeRequiredPersistenceReportsMissingAppGroup() throws {
    let controller = ProtectionRuntimeController(
        websiteBlockingController: SpyWebsiteBlockingController()
    )

    #expect(throws: SystemIntegrationError.missingAppGroupContainer("unconfigured")) {
        try controller.persistPolicyRequired(FermoPolicy())
    }
}

private final class SpyFermoStore: FermoStore, @unchecked Sendable {
    var savedSnapshots: [FermoSnapshot] = []

    func load() throws -> FermoSnapshot {
        FermoSnapshot()
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
