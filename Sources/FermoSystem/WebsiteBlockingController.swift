import FermoCore
import Foundation

#if canImport(NetworkExtension)
import NetworkExtension
#endif

public enum WebsiteBlockingStatus: String, Codable, Sendable {
    case unavailable
    case needsPermission
    case ready
    case active
}

public protocol WebsiteBlockingControlling: Sendable {
    func status() async -> WebsiteBlockingStatus
    func activate(policy: FermoPolicy) async throws
    func deactivate() async throws
    /// Install (but leave disabled) the filter configuration so onboarding can
    /// prompt for approval before any session runs.
    func prepare() async throws
    /// Rewrite the on-disk rule snapshot the running content filter reads, without
    /// touching the Network Extension configuration. Used to push live rule edits
    /// into an already-active session.
    func refreshRules(policy: FermoPolicy) async throws
}

public extension WebsiteBlockingControlling {
    func prepare() async throws {}
    func refreshRules(policy: FermoPolicy) async throws {}
}

public struct NetworkExtensionFilterConfiguration: Sendable {
    public var appGroupIdentifier: String?
    public var dataProviderBundleIdentifier: String
    public var snapshotFileName: String
    public var localizedDescription: String
    public var organization: String

    public init(
        appGroupIdentifier: String? = nil,
        dataProviderBundleIdentifier: String = "com.toolary.fermo.filter",
        snapshotFileName: String = ContentFilterRuleSnapshot.defaultFileName,
        localizedDescription: String = "Fermo Focus Filter",
        organization: String = "Toolary"
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.dataProviderBundleIdentifier = dataProviderBundleIdentifier
        self.snapshotFileName = snapshotFileName
        self.localizedDescription = localizedDescription
        self.organization = organization
    }
}

public struct NetworkExtensionWebsiteBlockingController: WebsiteBlockingControlling {
    private let configuration: NetworkExtensionFilterConfiguration

    public init(configuration: NetworkExtensionFilterConfiguration = NetworkExtensionFilterConfiguration()) {
        self.configuration = configuration
    }

    public func status() async -> WebsiteBlockingStatus {
        #if canImport(NetworkExtension)
        do {
            let manager = try await loadFilterManager()
            if manager.isEnabled {
                return .active
            }
            return manager.providerConfiguration == nil ? .needsPermission : .ready
        } catch {
            return .needsPermission
        }
        #else
        return .unavailable
        #endif
    }

    public func activate(policy: FermoPolicy) async throws {
        let appGroupIdentifier = try requiredAppGroupIdentifier()
        let snapshot = ContentFilterRuleSnapshot(policy: policy)
        try writeSnapshot(snapshot, appGroupIdentifier: appGroupIdentifier)

        #if canImport(NetworkExtension)
        let manager = try await loadFilterManager()
        manager.localizedDescription = configuration.localizedDescription
        manager.providerConfiguration = makeProviderConfiguration(appGroupIdentifier: appGroupIdentifier)
        manager.grade = .firewall
        manager.isEnabled = true
        try await saveFilterManager(manager)
        #else
        throw SystemIntegrationError.requiresSignedAppExtension
        #endif
    }

    /// Install the filter configuration ahead of time (disabled) so first-run
    /// onboarding can surface the macOS approval prompt without blocking anything
    /// yet. Starting a session later flips `isEnabled` on.
    public func prepare() async throws {
        let appGroupIdentifier = try requiredAppGroupIdentifier()
        try writeSnapshot(.inactive(), appGroupIdentifier: appGroupIdentifier)

        #if canImport(NetworkExtension)
        let manager = try await loadFilterManager()
        manager.localizedDescription = configuration.localizedDescription
        manager.providerConfiguration = makeProviderConfiguration(appGroupIdentifier: appGroupIdentifier)
        manager.grade = .firewall
        manager.isEnabled = false
        try await saveFilterManager(manager)
        #else
        throw SystemIntegrationError.requiresSignedAppExtension
        #endif
    }

    public func refreshRules(policy: FermoPolicy) async throws {
        let appGroupIdentifier = try requiredAppGroupIdentifier()
        try writeSnapshot(ContentFilterRuleSnapshot(policy: policy), appGroupIdentifier: appGroupIdentifier)
    }

    public func deactivate() async throws {
        try clearSnapshotIfConfigured()

        #if canImport(NetworkExtension)
        let manager = try await loadFilterManager()
        manager.isEnabled = false
        try await saveFilterManager(manager)
        #endif
    }

    private func requiredAppGroupIdentifier() throws -> String {
        guard let appGroupIdentifier = configuration.appGroupIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !appGroupIdentifier.isEmpty,
            !appGroupIdentifier.hasPrefix("$(")
        else {
            throw SystemIntegrationError.missingAppGroupContainer("unconfigured")
        }

        return appGroupIdentifier
    }

    private func writeSnapshot(_ snapshot: ContentFilterRuleSnapshot, appGroupIdentifier: String) throws {
        guard let snapshotURL = ContentFilterRuleSnapshotStore.defaultURL(
            appGroupIdentifier: appGroupIdentifier,
            fileName: configuration.snapshotFileName
        ) else {
            throw SystemIntegrationError.missingAppGroupContainer(appGroupIdentifier)
        }
        try ContentFilterRuleSnapshotStore(fileURL: snapshotURL).write(snapshot)
    }

    private func clearSnapshotIfConfigured() throws {
        guard let appGroupIdentifier = configuration.appGroupIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !appGroupIdentifier.isEmpty,
            !appGroupIdentifier.hasPrefix("$(")
        else {
            return
        }

        try writeSnapshot(.inactive(), appGroupIdentifier: appGroupIdentifier)
    }

    #if canImport(NetworkExtension)
    private func makeProviderConfiguration(appGroupIdentifier: String) -> NEFilterProviderConfiguration {
        let providerConfiguration = NEFilterProviderConfiguration()
        providerConfiguration.filterSockets = true
        providerConfiguration.filterDataProviderBundleIdentifier = configuration.dataProviderBundleIdentifier
        providerConfiguration.organization = configuration.organization
        providerConfiguration.serverAddress = "Fermo local content filter"
        providerConfiguration.vendorConfiguration = [
            "FermoAppGroupIdentifier": appGroupIdentifier,
            "FermoSnapshotFileName": configuration.snapshotFileName
        ]
        return providerConfiguration
    }

    private func loadFilterManager() async throws -> NEFilterManager {
        let manager = NEFilterManager.shared()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        return manager
    }

    private func saveFilterManager(_ manager: NEFilterManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    #endif
}
