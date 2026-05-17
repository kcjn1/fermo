import Foundation

public struct FermoPolicy: Codable, Equatable, Sendable {
    public var blocklists: [Blocklist]
    public var sessions: [FocusSession]

    public init(blocklists: [Blocklist] = [], sessions: [FocusSession] = []) {
        self.blocklists = blocklists
        self.sessions = sessions
    }

    public func activeSessions(at date: Date) -> [FocusSession] {
        sessions.filter { $0.isActive(at: date) }
    }

    public func activeBlocklists(at date: Date) -> [Blocklist] {
        let activeIDs = Set(activeSessions(at: date).flatMap(\.blocklistIDs))
        return blocklists.filter { $0.isEnabled && activeIDs.contains($0.id) }
    }

    public func shouldBlock(host: String, at date: Date = Date()) -> Bool {
        activeBlocklists(at: date).contains { blocklist in
            blocklist.domainRules.contains { $0.matches(host: host) }
        }
    }

    public func blockedAppBundleIdentifiers(at date: Date = Date()) -> Set<String> {
        Set(activeBlocklists(at: date).flatMap { blocklist in
            blocklist.appRules.map(\.bundleIdentifier)
        })
    }
}
