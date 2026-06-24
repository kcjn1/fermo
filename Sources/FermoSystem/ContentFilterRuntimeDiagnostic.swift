import FermoCore
import Foundation

public enum ContentFilterRuntimeDiagnosticState: String, Equatable, Sendable {
    case ready
    case noActiveRules
    case expiredSnapshot
    case missingSnapshot
    case unreadableSnapshot
}

public struct ContentFilterRuntimeDiagnostic: Equatable, Sendable {
    public var state: ContentFilterRuntimeDiagnosticState
    public var snapshotPath: String
    public var activeSessionsCount: Int
    public var mode: FocusMode
    public var blockedDomains: [String]
    public var allowedDomains: [String]
    public var expiresAt: Date?
    public var summary: String

    public init(
        state: ContentFilterRuntimeDiagnosticState,
        snapshotPath: String,
        activeSessionsCount: Int,
        mode: FocusMode,
        blockedDomains: [String],
        allowedDomains: [String],
        expiresAt: Date?,
        summary: String
    ) {
        self.state = state
        self.snapshotPath = snapshotPath
        self.activeSessionsCount = activeSessionsCount
        self.mode = mode
        self.blockedDomains = blockedDomains
        self.allowedDomains = allowedDomains
        self.expiresAt = expiresAt
        self.summary = summary
    }

    public static func inspect(
        _ snapshotURL: URL,
        at date: Date = Date()
    ) -> ContentFilterRuntimeDiagnostic {
        let snapshotPath = snapshotURL.path

        guard FileManager.default.fileExists(atPath: snapshotPath) else {
            return ContentFilterRuntimeDiagnostic(
                state: .missingSnapshot,
                snapshotPath: snapshotPath,
                activeSessionsCount: 0,
                mode: .blocklist,
                blockedDomains: [],
                allowedDomains: [],
                expiresAt: nil,
                summary: "Content filter rule snapshot is missing; website blocking will allow by default."
            )
        }

        let snapshot: ContentFilterRuleSnapshot
        do {
            snapshot = try ContentFilterRuleSnapshotStore(fileURL: snapshotURL).load() ?? .inactive(at: date)
        } catch {
            return ContentFilterRuntimeDiagnostic(
                state: .unreadableSnapshot,
                snapshotPath: snapshotPath,
                activeSessionsCount: 0,
                mode: .blocklist,
                blockedDomains: [],
                allowedDomains: [],
                expiresAt: nil,
                summary: "Content filter rule snapshot could not be read: \(error.localizedDescription)"
            )
        }

        if let expiresAt = snapshot.expiresAt, date >= expiresAt {
            return ContentFilterRuntimeDiagnostic(
                state: .expiredSnapshot,
                snapshotPath: snapshotPath,
                activeSessionsCount: 0,
                mode: snapshot.mode,
                blockedDomains: snapshot.normalizedBlockedDomains,
                allowedDomains: snapshot.normalizedAllowedDomains,
                expiresAt: expiresAt,
                summary: "Content filter rule snapshot is expired; website blocking should allow by default."
            )
        }

        let activeSessionsCount = snapshot.activeSessionIDs.count
        let blockedDomains = snapshot.normalizedBlockedDomains
        let allowedDomains = snapshot.normalizedAllowedDomains
        guard activeSessionsCount > 0, !blockedDomains.isEmpty || !allowedDomains.isEmpty else {
            return ContentFilterRuntimeDiagnostic(
                state: .noActiveRules,
                snapshotPath: snapshotPath,
                activeSessionsCount: activeSessionsCount,
                mode: snapshot.mode,
                blockedDomains: blockedDomains,
                allowedDomains: allowedDomains,
                expiresAt: snapshot.expiresAt,
                summary: "Content filter rule snapshot is readable, but no active website rules are present."
            )
        }

        let ruleSummary: String
        switch snapshot.mode {
        case .blocklist:
            ruleSummary = "\(blockedDomains.count) \(plural("blocked domain", blockedDomains.count))"
        case .focusRoom:
            ruleSummary = "\(allowedDomains.count) \(plural("allowed domain", allowedDomains.count)), \(blockedDomains.count) explicit \(plural("blocked domain", blockedDomains.count))"
        }

        return ContentFilterRuntimeDiagnostic(
            state: .ready,
            snapshotPath: snapshotPath,
            activeSessionsCount: activeSessionsCount,
            mode: snapshot.mode,
            blockedDomains: blockedDomains,
            allowedDomains: allowedDomains,
            expiresAt: snapshot.expiresAt,
            summary: "\(activeSessionsCount) \(plural("active session", activeSessionsCount)), \(ruleSummary) in Content Filter snapshot."
        )
    }

    private static func plural(_ singular: String, _ count: Int) -> String {
        count == 1 ? singular : "\(singular)s"
    }
}
