import FermoCore
import Foundation

public enum ProtectionRuntimeTeardownKind: Equatable, Sendable {
    case websiteSpike
    case appSpike
    case helperSpike
    case allDiagnostics

    var deactivatesWebsiteBlocking: Bool {
        self != .appSpike
    }

    var allowedDiagnosticSessionTitles: Set<String> {
        switch self {
        case .websiteSpike:
            return ["Website Blocking Spike"]
        case .appSpike:
            return ["App Blocking Spike"]
        case .helperSpike:
            return ["Helper Persistence Spike"]
        case .allDiagnostics:
            return [
                "Website Blocking Spike",
                "App Blocking Spike",
                "Helper Persistence Spike"
            ]
        }
    }
}

public struct ProtectionRuntimeTeardownResult: Equatable, Sendable {
    public var policy: FermoPolicy
    public var didClearPersistedPolicy: Bool
    public var didDeactivateWebsiteBlocking: Bool

    public init(
        policy: FermoPolicy,
        didClearPersistedPolicy: Bool,
        didDeactivateWebsiteBlocking: Bool
    ) {
        self.policy = policy
        self.didClearPersistedPolicy = didClearPersistedPolicy
        self.didDeactivateWebsiteBlocking = didDeactivateWebsiteBlocking
    }
}

public struct ProtectionRuntimeController: Sendable {
    private let store: (any FermoStore)?
    private let websiteBlockingController: any WebsiteBlockingControlling
    private let lockedModeGuard: LockedModeGuard

    public init(
        store: (any FermoStore)? = nil,
        websiteBlockingController: any WebsiteBlockingControlling,
        lockedModeGuard: LockedModeGuard = LockedModeGuard()
    ) {
        self.store = store
        self.websiteBlockingController = websiteBlockingController
        self.lockedModeGuard = lockedModeGuard
    }

    @discardableResult
    public func persistPolicy(_ policy: FermoPolicy) throws -> Bool {
        guard let store else {
            return false
        }

        try store.save(snapshotPreservingSchedules(for: policy))
        return true
    }

    public func persistPolicyRequired(_ policy: FermoPolicy) throws {
        guard let store else {
            throw SystemIntegrationError.missingAppGroupContainer("unconfigured")
        }

        try store.save(snapshotPreservingSchedules(for: policy))
    }

    public func stopDiagnosticProtection(
        kind: ProtectionRuntimeTeardownKind,
        currentPolicy: FermoPolicy,
        at date: Date = Date()
    ) async throws -> ProtectionRuntimeTeardownResult {
        try validateDiagnosticTeardown(kind: kind, currentPolicy: currentPolicy)
        try lockedModeGuard.validate(.endSession, for: currentPolicy, at: date)

        var didDeactivateWebsiteBlocking = false
        if kind.deactivatesWebsiteBlocking {
            try await websiteBlockingController.deactivate()
            didDeactivateWebsiteBlocking = true
        }

        let clearedPolicy = FermoPolicy(evidenceLog: currentPolicy.evidenceLog)
        let didClearPersistedPolicy = try clearPersistedPolicyIfPossible(policy: clearedPolicy)
        return ProtectionRuntimeTeardownResult(
            policy: clearedPolicy,
            didClearPersistedPolicy: didClearPersistedPolicy,
            didDeactivateWebsiteBlocking: didDeactivateWebsiteBlocking
        )
    }

    @discardableResult
    public func deactivateWebsiteBlockingAfterTerminalPolicy(
        _ policy: FermoPolicy,
        at date: Date = Date()
    ) async throws -> ProtectionRuntimeTeardownResult {
        guard policy.activeSessions(at: date).isEmpty else {
            return ProtectionRuntimeTeardownResult(
                policy: policy,
                didClearPersistedPolicy: false,
                didDeactivateWebsiteBlocking: false
            )
        }

        try await websiteBlockingController.deactivate()
        return ProtectionRuntimeTeardownResult(
            policy: policy,
            didClearPersistedPolicy: false,
            didDeactivateWebsiteBlocking: true
        )
    }

    private func validateDiagnosticTeardown(
        kind: ProtectionRuntimeTeardownKind,
        currentPolicy: FermoPolicy
    ) throws {
        let protectedSessions = currentPolicy.sessions.filter { session in
            session.state == .active || session.state == .scheduled
        }
        guard !protectedSessions.isEmpty else {
            return
        }

        let allowedTitles = kind.allowedDiagnosticSessionTitles
        let nonDiagnosticTitles = protectedSessions
            .map(\.title)
            .filter { !allowedTitles.contains($0) }

        if let title = nonDiagnosticTitles.first {
            throw SystemIntegrationError.diagnosticTeardownRejected(title)
        }
    }

    private func clearPersistedPolicyIfPossible(policy: FermoPolicy) throws -> Bool {
        guard let store else {
            return false
        }

        let snapshot = try store.load()
        try store.save(FermoSnapshot(
            policy: policy,
            schedules: snapshot.schedules,
            preferences: snapshot.preferences
        ))
        return true
    }

    private func snapshotPreservingSchedules(for policy: FermoPolicy) throws -> FermoSnapshot {
        guard let store else {
            return FermoSnapshot(policy: policy)
        }

        let snapshot = try store.load()
        return FermoSnapshot(
            policy: policy,
            schedules: snapshot.schedules,
            preferences: snapshot.preferences
        )
    }
}
