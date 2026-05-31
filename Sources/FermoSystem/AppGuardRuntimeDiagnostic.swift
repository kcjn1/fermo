import FermoCore
import Foundation

public enum AppGuardRuntimeDiagnosticState: String, Equatable, Sendable {
    case ready
    case noActivePolicy
    case missingSnapshot
    case unreadableSnapshot
}

public struct AppGuardRuntimeDiagnostic: Equatable, Sendable {
    public var state: AppGuardRuntimeDiagnosticState
    public var snapshotPath: String
    public var activeSessionsCount: Int
    public var protectedAppBundleIdentifiers: [String]
    public var summary: String

    public init(
        state: AppGuardRuntimeDiagnosticState,
        snapshotPath: String,
        activeSessionsCount: Int,
        protectedAppBundleIdentifiers: [String],
        summary: String
    ) {
        self.state = state
        self.snapshotPath = snapshotPath
        self.activeSessionsCount = activeSessionsCount
        self.protectedAppBundleIdentifiers = protectedAppBundleIdentifiers
        self.summary = summary
    }

    public static func inspect(
        _ snapshotURL: URL,
        at date: Date = Date()
    ) -> AppGuardRuntimeDiagnostic {
        let snapshotPath = snapshotURL.path

        guard FileManager.default.fileExists(atPath: snapshotPath) else {
            return AppGuardRuntimeDiagnostic(
                state: .missingSnapshot,
                snapshotPath: snapshotPath,
                activeSessionsCount: 0,
                protectedAppBundleIdentifiers: [],
                summary: "App Guard policy snapshot is missing; app launch enforcement will allow by default."
            )
        }

        let snapshot: FermoSnapshot
        do {
            snapshot = try JSONFileFermoStore(url: snapshotURL).load()
        } catch {
            return AppGuardRuntimeDiagnostic(
                state: .unreadableSnapshot,
                snapshotPath: snapshotPath,
                activeSessionsCount: 0,
                protectedAppBundleIdentifiers: [],
                summary: "App Guard policy snapshot could not be read: \(error.localizedDescription)"
            )
        }

        let policy = snapshot.policy
        let activeSessions = policy.activeSessions(at: date)
        let protectedApps = Array(policy.blockedAppBundleIdentifiers(at: date)).sorted()

        guard !activeSessions.isEmpty else {
            return AppGuardRuntimeDiagnostic(
                state: .noActivePolicy,
                snapshotPath: snapshotPath,
                activeSessionsCount: 0,
                protectedAppBundleIdentifiers: [],
                summary: "App Guard policy snapshot is readable, but no protected session is active."
            )
        }

        return AppGuardRuntimeDiagnostic(
            state: .ready,
            snapshotPath: snapshotPath,
            activeSessionsCount: activeSessions.count,
            protectedAppBundleIdentifiers: protectedApps,
            summary: "\(activeSessions.count) \(plural("active session", activeSessions.count)), \(protectedApps.count) \(plural("protected app", protectedApps.count)) in App Guard snapshot."
        )
    }

    private static func plural(_ singular: String, _ count: Int) -> String {
        count == 1 ? singular : "\(singular)s"
    }
}
