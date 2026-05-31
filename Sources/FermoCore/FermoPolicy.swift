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
        if activeBlocklists(at: date).contains(where: { blocklist in
            blocklist.domainRules.contains { $0.matches(host: host) }
        }) {
            return true
        }

        let focusRoomContracts = activeFocusRoomContracts(at: date)
        if !focusRoomContracts.isEmpty {
            return !focusRoomContracts.allSatisfy { contract in
                contract.allowedDomains.contains { $0.matches(host: host) }
            }
        }

        return false
    }

    /// Bundle identifiers blocked by an active blocklist, in their authored (display) casing.
    /// Matching against these is case-insensitive (see `shouldInterruptApp`) because bundle
    /// identifiers are conventionally case-insensitive, but the stored casing is preserved so
    /// diagnostics surface exactly what the user entered.
    public func blockedAppBundleIdentifiers(at date: Date = Date()) -> Set<String> {
        Set(activeBlocklists(at: date).flatMap { blocklist in
            blocklist.appRules.map(\.bundleIdentifier)
        })
    }

    public func shouldInterruptApp(bundleIdentifier: String, at date: Date = Date()) -> Bool {
        let normalized = bundleIdentifier.lowercased()
        if blockedAppBundleIdentifiers(at: date).contains(where: { $0.lowercased() == normalized }) {
            return true
        }

        if !activeFocusRoomContracts(at: date).isEmpty {
            return !isAppAllowedInFocusRoom(bundleIdentifier: bundleIdentifier, at: date)
        }

        return false
    }

    public func isAppAllowedInFocusRoom(bundleIdentifier: String, at date: Date = Date()) -> Bool {
        let contracts = activeFocusRoomContracts(at: date)
        guard !contracts.isEmpty else { return true }
        let normalized = bundleIdentifier.lowercased()
        return contracts.allSatisfy { contract in
            contract.allowedApps.contains { $0.normalizedBundleIdentifier == normalized }
        }
    }

    private func activeFocusRoomContracts(at date: Date) -> [FocusContract] {
        activeSessions(at: date).compactMap(\.contract).filter(\.isFocusRoom)
    }
}
