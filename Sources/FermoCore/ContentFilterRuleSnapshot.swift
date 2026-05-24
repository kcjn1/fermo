import Foundation

public enum ContentFilterRuleDecision: String, Codable, Equatable, Sendable {
    case allow
    case block
}

public struct ContentFilterRuleSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let defaultFileName = "FermoContentFilterRules.json"

    public var version: Int
    public var generatedAt: Date
    public var activeSessionIDs: [UUID]
    public var mode: FocusMode
    public var blockedDomains: [DomainRule]
    public var allowedDomains: [DomainRule]
    public var expiresAt: Date?

    public init(
        version: Int = Self.currentVersion,
        generatedAt: Date = Date(),
        activeSessionIDs: [UUID] = [],
        mode: FocusMode = .blocklist,
        blockedDomains: [DomainRule] = [],
        allowedDomains: [DomainRule] = [],
        expiresAt: Date? = nil
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.activeSessionIDs = activeSessionIDs
        self.mode = mode
        self.blockedDomains = blockedDomains
        self.allowedDomains = allowedDomains
        self.expiresAt = expiresAt
    }

    public init(policy: FermoPolicy, at date: Date = Date()) {
        let activeSessions = policy.activeSessions(at: date)
        let focusRoomSessions = activeSessions.filter { $0.contract?.isFocusRoom == true }
        let isFocusRoom = !focusRoomSessions.isEmpty

        self.init(
            generatedAt: date,
            activeSessionIDs: activeSessions.map(\.id),
            mode: isFocusRoom ? .focusRoom : .blocklist,
            blockedDomains: isFocusRoom ? [] : policy.activeBlocklists(at: date).flatMap(\.domainRules).deduplicated(),
            allowedDomains: focusRoomSessions.compactMap(\.contract).flatMap(\.allowedDomains).deduplicated(),
            expiresAt: activeSessions.map(\.endsAt).max()
        )
    }

    public static func redditYouTubeSpike(now: Date = Date(), duration: TimeInterval = 60 * 60) throws -> Self {
        let blocklist = Blocklist(
            name: "Network Extension Spike",
            domainRules: [
                try DomainRule("reddit.com"),
                try DomainRule("youtube.com")
            ]
        )
        let session = try FocusSession(
            title: "Network Extension Spike",
            blocklistIDs: [blocklist.id],
            startsAt: now,
            duration: duration,
            state: .active
        )
        return ContentFilterRuleSnapshot(
            policy: FermoPolicy(blocklists: [blocklist], sessions: [session]),
            at: now
        )
    }

    public static func inactive(at date: Date = Date()) -> Self {
        ContentFilterRuleSnapshot(generatedAt: date, expiresAt: date)
    }

    public func decision(for host: String, at date: Date = Date()) -> ContentFilterRuleDecision {
        if let expiresAt, date >= expiresAt {
            return .allow
        }

        switch mode {
        case .blocklist:
            return blockedDomains.contains { $0.matches(host: host) } ? .block : .allow
        case .focusRoom:
            return allowedDomains.contains { $0.matches(host: host) } ? .allow : .block
        }
    }

    public var normalizedBlockedDomains: [String] {
        blockedDomains.map(\.normalizedPattern).sorted()
    }

    public var normalizedAllowedDomains: [String] {
        allowedDomains.map(\.normalizedPattern).sorted()
    }
}

public struct ContentFilterRuleSnapshotStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> ContentFilterRuleSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.fermoContentFilter.decode(ContentFilterRuleSnapshot.self, from: data)
    }

    public func write(_ snapshot: ContentFilterRuleSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.fermoContentFilter.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    public static func defaultURL(
        appGroupIdentifier: String,
        fileName: String = ContentFilterRuleSnapshot.defaultFileName
    ) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }
}

private extension Array where Element: Hashable {
    func deduplicated() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension JSONDecoder {
    static var fermoContentFilter: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var fermoContentFilter: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
