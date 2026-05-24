import FermoCore
import Foundation

public enum ProtectionRuntimeTeardownKind: Equatable, Sendable {
    case websiteSpike
    case appSpike
    case helperSpike

    var deactivatesWebsiteBlocking: Bool {
        self != .appSpike
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

        try store.save(FermoSnapshot(policy: policy))
        return true
    }

    public func persistPolicyRequired(_ policy: FermoPolicy) throws {
        guard let store else {
            throw SystemIntegrationError.missingAppGroupContainer("unconfigured")
        }

        try store.save(FermoSnapshot(policy: policy))
    }

    public func stopDiagnosticProtection(
        kind: ProtectionRuntimeTeardownKind,
        currentPolicy: FermoPolicy,
        at date: Date = Date()
    ) async throws -> ProtectionRuntimeTeardownResult {
        try lockedModeGuard.validate(.endSession, for: currentPolicy, at: date)

        var didDeactivateWebsiteBlocking = false
        if kind.deactivatesWebsiteBlocking {
            try await websiteBlockingController.deactivate()
            didDeactivateWebsiteBlocking = true
        }

        let didClearPersistedPolicy = try clearPersistedPolicyIfPossible()
        return ProtectionRuntimeTeardownResult(
            policy: FermoPolicy(),
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

    private func clearPersistedPolicyIfPossible() throws -> Bool {
        guard let store else {
            return false
        }

        try store.save(FermoSnapshot())
        return true
    }
}
