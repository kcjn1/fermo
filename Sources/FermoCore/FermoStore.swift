import Foundation

public struct FermoSnapshot: Codable, Equatable, Sendable {
    public var blocklists: [Blocklist]
    public var sessions: [FocusSession]
    public var schedules: [WeeklySchedule]

    public init(
        blocklists: [Blocklist] = [],
        sessions: [FocusSession] = [],
        schedules: [WeeklySchedule] = []
    ) {
        self.blocklists = blocklists
        self.sessions = sessions
        self.schedules = schedules
    }
}

public protocol FermoStore: Sendable {
    func load() throws -> FermoSnapshot
    func save(_ snapshot: FermoSnapshot) throws
}

public final class JSONFileFermoStore: FermoStore, @unchecked Sendable {
    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL) {
        self.url = url
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> FermoSnapshot {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return FermoSnapshot()
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(FermoSnapshot.self, from: data)
    }

    public func save(_ snapshot: FermoSnapshot) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])
    }
}
