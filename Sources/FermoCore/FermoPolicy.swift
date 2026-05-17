import Foundation

public struct FermoPolicy: Codable, Equatable, Sendable {
    public var blocklists: [Blocklist]
    public var sessions: [FocusSession]
    public var evidenceLog: [EvidenceLogEntry]

    public init(blocklists: [Blocklist] = [], sessions: [FocusSession] = [], evidenceLog: [EvidenceLogEntry] = []) {
        self.blocklists = blocklists
        self.sessions = sessions
        self.evidenceLog = evidenceLog
    }

    public func activeSessions(at date: Date) -> [FocusSession] {
        sessions.filter { $0.isActive(at: date) }
    }

    public func activeBlocklists(at date: Date) -> [Blocklist] {
        let activeIDs = Set(activeSessions(at: date).flatMap(\.blocklistIDs))
        return blocklists.filter { $0.isEnabled && activeIDs.contains($0.id) }
    }

    public func shouldBlock(host: String, at date: Date = Date()) -> Bool {
        let sessions = activeSessions(at: date)
        let focusRoomContracts = sessions.compactMap(\.contract).filter(\.isFocusRoom)
        if !focusRoomContracts.isEmpty {
            return !focusRoomContracts.contains { contract in
                contract.allowedDomains.contains { $0.matches(host: host) }
            }
        }

        return activeBlocklists(at: date).contains { blocklist in
            blocklist.domainRules.contains { $0.matches(host: host) }
        }
    }

    public func blockedAppBundleIdentifiers(at date: Date = Date()) -> Set<String> {
        Set(activeBlocklists(at: date).flatMap { blocklist in
            blocklist.appRules.map(\.bundleIdentifier)
        })
    }

    public func shouldInterruptApp(bundleIdentifier: String, at date: Date = Date()) -> Bool {
        let contracts = activeSessions(at: date).compactMap(\.contract).filter(\.isFocusRoom)
        if !contracts.isEmpty {
            return !isAppAllowedInFocusRoom(bundleIdentifier: bundleIdentifier, at: date)
        }
        return blockedAppBundleIdentifiers(at: date).contains(bundleIdentifier)
    }

    public func isAppAllowedInFocusRoom(bundleIdentifier: String, at date: Date = Date()) -> Bool {
        let contracts = activeSessions(at: date).compactMap(\.contract).filter(\.isFocusRoom)
        guard !contracts.isEmpty else { return true }
        return contracts.contains { contract in
            contract.allowedApps.contains { $0.bundleIdentifier == bundleIdentifier }
        }
    }
}
