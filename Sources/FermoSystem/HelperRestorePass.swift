import FermoCore
import Foundation

public protocol ContentFilterRuleSnapshotWriting: Sendable {
    func write(_ snapshot: ContentFilterRuleSnapshot) throws
}

extension ContentFilterRuleSnapshotStore: ContentFilterRuleSnapshotWriting {}

public struct HelperRestorePassState: Equatable, Sendable {
    public var didSeeActiveSession: Bool
    public var didRunEmptyCleanup: Bool
    public var lastRuleSnapshot: ContentFilterRuleSnapshot?

    public init(
        didSeeActiveSession: Bool = false,
        didRunEmptyCleanup: Bool = false,
        lastRuleSnapshot: ContentFilterRuleSnapshot? = nil
    ) {
        self.didSeeActiveSession = didSeeActiveSession
        self.didRunEmptyCleanup = didRunEmptyCleanup
        self.lastRuleSnapshot = lastRuleSnapshot
    }
}

public struct HelperRestorePassResult: Equatable, Sendable {
    public var snapshot: FermoSnapshot
    public var didSaveSnapshot: Bool
    public var didWriteRuleSnapshot: Bool
    public var didClearRuleSnapshot: Bool
    public var activeSessionsCount: Int

    public init(
        snapshot: FermoSnapshot,
        didSaveSnapshot: Bool,
        didWriteRuleSnapshot: Bool,
        didClearRuleSnapshot: Bool,
        activeSessionsCount: Int
    ) {
        self.snapshot = snapshot
        self.didSaveSnapshot = didSaveSnapshot
        self.didWriteRuleSnapshot = didWriteRuleSnapshot
        self.didClearRuleSnapshot = didClearRuleSnapshot
        self.activeSessionsCount = activeSessionsCount
    }
}

public struct LaunchRestorePassResult: Equatable, Sendable {
    public var snapshot: FermoSnapshot
    public var didSaveSnapshot: Bool
    public var activeSessionsCount: Int

    public init(
        snapshot: FermoSnapshot,
        didSaveSnapshot: Bool,
        activeSessionsCount: Int
    ) {
        self.snapshot = snapshot
        self.didSaveSnapshot = didSaveSnapshot
        self.activeSessionsCount = activeSessionsCount
    }
}

public struct LaunchRestorePass: Sendable {
    private let store: any FermoStore
    private let scheduleRestorer: ScheduleRestorer
    private let dueSessionActivator: DueSessionActivator

    public init(
        store: any FermoStore,
        scheduleRestorer: ScheduleRestorer = ScheduleRestorer(),
        dueSessionActivator: DueSessionActivator = DueSessionActivator()
    ) {
        self.store = store
        self.scheduleRestorer = scheduleRestorer
        self.dueSessionActivator = dueSessionActivator
    }

    public func run(at date: Date = Date()) throws -> LaunchRestorePassResult {
        let snapshot = try store.load()
        let restoredSnapshot = try Self.restoredSnapshot(
            from: snapshot,
            at: date,
            scheduleRestorer: scheduleRestorer,
            dueSessionActivator: dueSessionActivator
        )
        let didSaveSnapshot = restoredSnapshot != snapshot

        if didSaveSnapshot {
            try store.save(restoredSnapshot)
        }

        return LaunchRestorePassResult(
            snapshot: restoredSnapshot,
            didSaveSnapshot: didSaveSnapshot,
            activeSessionsCount: restoredSnapshot.policy.activeSessions(at: date).count
        )
    }

    fileprivate static func restoredSnapshot(
        from snapshot: FermoSnapshot,
        at date: Date,
        scheduleRestorer: ScheduleRestorer,
        dueSessionActivator: DueSessionActivator
    ) throws -> FermoSnapshot {
        var restoredSnapshot = try scheduleRestorer.restoringDueSessions(in: snapshot, at: date).snapshot
        let activationResult = dueSessionActivator.activatingDueSessions(in: restoredSnapshot.policy, at: date)

        if activationResult.didChange {
            restoredSnapshot = FermoSnapshot(
                policy: activationResult.policy,
                schedules: restoredSnapshot.schedules,
                preferences: restoredSnapshot.preferences
            )
        }

        return restoredSnapshot
    }
}

public struct HelperRestorePass: Sendable {
    private let store: any FermoStore
    private let ruleSnapshotStore: any ContentFilterRuleSnapshotWriting
    private let scheduleRestorer: ScheduleRestorer
    private let dueSessionActivator: DueSessionActivator

    public init(
        store: any FermoStore,
        ruleSnapshotStore: any ContentFilterRuleSnapshotWriting,
        scheduleRestorer: ScheduleRestorer = ScheduleRestorer(),
        dueSessionActivator: DueSessionActivator = DueSessionActivator()
    ) {
        self.store = store
        self.ruleSnapshotStore = ruleSnapshotStore
        self.scheduleRestorer = scheduleRestorer
        self.dueSessionActivator = dueSessionActivator
    }

    public func run(
        at date: Date = Date(),
        state: inout HelperRestorePassState
    ) throws -> HelperRestorePassResult {
        let snapshot = try store.load()
        let restoredSnapshot = try LaunchRestorePass.restoredSnapshot(
            from: snapshot,
            at: date,
            scheduleRestorer: scheduleRestorer,
            dueSessionActivator: dueSessionActivator
        )
        let didSaveSnapshot = restoredSnapshot != snapshot

        if didSaveSnapshot {
            try store.save(restoredSnapshot)
        }

        let policy = restoredSnapshot.policy
        let activeSessions = policy.activeSessions(at: date)

        if activeSessions.isEmpty {
            return try clearRuleSnapshotIfNeeded(
                snapshot: restoredSnapshot,
                at: date,
                state: &state
            )
        }

        let ruleSnapshot = ContentFilterRuleSnapshot(policy: policy, at: date)
        let didWriteRuleSnapshot = !ruleSnapshot.hasSameRules(as: state.lastRuleSnapshot)
        if didWriteRuleSnapshot {
            try ruleSnapshotStore.write(ruleSnapshot)
            state.lastRuleSnapshot = ruleSnapshot
        }

        state.didSeeActiveSession = true
        state.didRunEmptyCleanup = false

        return HelperRestorePassResult(
            snapshot: restoredSnapshot,
            didSaveSnapshot: didSaveSnapshot,
            didWriteRuleSnapshot: didWriteRuleSnapshot,
            didClearRuleSnapshot: false,
            activeSessionsCount: activeSessions.count
        )
    }

    private func clearRuleSnapshotIfNeeded(
        snapshot: FermoSnapshot,
        at date: Date,
        state: inout HelperRestorePassState
    ) throws -> HelperRestorePassResult {
        var didClearRuleSnapshot = false

        if state.didSeeActiveSession || !state.didRunEmptyCleanup {
            let inactiveSnapshot = ContentFilterRuleSnapshot.inactive(at: date)
            try ruleSnapshotStore.write(inactiveSnapshot)
            state.lastRuleSnapshot = inactiveSnapshot
            didClearRuleSnapshot = true
        }

        state.didSeeActiveSession = false
        state.didRunEmptyCleanup = true

        return HelperRestorePassResult(
            snapshot: snapshot,
            didSaveSnapshot: false,
            didWriteRuleSnapshot: didClearRuleSnapshot,
            didClearRuleSnapshot: didClearRuleSnapshot,
            activeSessionsCount: 0
        )
    }
}

private extension ContentFilterRuleSnapshot {
    func hasSameRules(as other: ContentFilterRuleSnapshot?) -> Bool {
        guard let other else {
            return false
        }

        return activeSessionIDs == other.activeSessionIDs
            && mode == other.mode
            && blockedDomains == other.blockedDomains
            && allowedDomains == other.allowedDomains
            && allowedDomainGroups == other.allowedDomainGroups
            && expiresAt == other.expiresAt
    }
}
