import FermoCore
import Foundation

public struct AppGuardPolicyStore: Sendable {
    public typealias AppGroupContainerResolver = @Sendable (String) -> URL?

    private let store: any FermoStore
    private let enforcementPolicy: AppEnforcementPolicy

    public init(
        snapshotURL: URL,
        enforcementPolicy: AppEnforcementPolicy = AppEnforcementPolicy()
    ) {
        self.init(
            store: JSONFileFermoStore(url: snapshotURL),
            enforcementPolicy: enforcementPolicy
        )
    }

    public init(
        store: any FermoStore,
        enforcementPolicy: AppEnforcementPolicy = AppEnforcementPolicy()
    ) {
        self.store = store
        self.enforcementPolicy = enforcementPolicy
    }

    public func decision(
        for context: AppLaunchContext,
        at date: Date = Date()
    ) throws -> AppEnforcementDecision {
        let snapshot = try store.load()
        return enforcementPolicy.decision(
            for: context,
            policy: snapshot.policy,
            at: date
        )
    }

    public static func defaultSnapshotURL(
        appGroupIdentifier: String,
        containerURL: AppGroupContainerResolver = { identifier in
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        }
    ) -> URL? {
        containerURL(appGroupIdentifier)?
            .appendingPathComponent(JSONFileFermoStore.defaultFileName)
    }
}
