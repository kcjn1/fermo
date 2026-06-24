import Foundation

public struct FermoPreferences: Codable, Equatable, Sendable {
    public var evidenceExportDirectoryPath: String?
    public var defaultPresetID: String?
    public var defaultRigor: ContractRigor
    public var defaultDurationMinutes: Int

    public init(
        evidenceExportDirectoryPath: String? = nil,
        defaultPresetID: String? = nil,
        defaultRigor: ContractRigor = .locked,
        defaultDurationMinutes: Int = 90
    ) {
        let trimmed = evidenceExportDirectoryPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.evidenceExportDirectoryPath = trimmed?.isEmpty == true ? nil : trimmed
        let trimmedPresetID = defaultPresetID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.defaultPresetID = trimmedPresetID?.isEmpty == true ? nil : trimmedPresetID
        self.defaultRigor = defaultRigor
        self.defaultDurationMinutes = min(max(defaultDurationMinutes, 25), 180)
    }

    public init(evidenceExportDirectoryPath: String?) {
        self.init(
            evidenceExportDirectoryPath: evidenceExportDirectoryPath,
            defaultPresetID: nil,
            defaultRigor: .locked,
            defaultDurationMinutes: 90
        )
    }

    private enum CodingKeys: String, CodingKey {
        case evidenceExportDirectoryPath
        case defaultPresetID
        case defaultRigor
        case defaultDurationMinutes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            evidenceExportDirectoryPath: try container.decodeIfPresent(String.self, forKey: .evidenceExportDirectoryPath),
            defaultPresetID: try container.decodeIfPresent(String.self, forKey: .defaultPresetID),
            defaultRigor: try container.decodeIfPresent(ContractRigor.self, forKey: .defaultRigor) ?? .locked,
            defaultDurationMinutes: try container.decodeIfPresent(Int.self, forKey: .defaultDurationMinutes) ?? 90
        )
    }
}

public struct FermoSnapshot: Codable, Equatable, Sendable {
    public var blocklists: [Blocklist]
    public var sessions: [FocusSession]
    public var schedules: [WeeklySchedule]
    public var evidenceLog: [EvidenceLogEntry]
    public var preferences: FermoPreferences
    /// Operator-saved presets, in addition to the built-in `FocusPresetLibrary.defaults()`.
    public var customPresets: [FocusPreset]
    /// A single resumable Start Contract draft, if the operator saved one.
    public var savedDraft: SavedContractDraft?

    public init(
        blocklists: [Blocklist] = [],
        sessions: [FocusSession] = [],
        schedules: [WeeklySchedule] = [],
        evidenceLog: [EvidenceLogEntry] = []
    ) {
        self.init(
            blocklists: blocklists,
            sessions: sessions,
            schedules: schedules,
            evidenceLog: evidenceLog,
            preferences: FermoPreferences()
        )
    }

    public init(
        blocklists: [Blocklist] = [],
        sessions: [FocusSession] = [],
        schedules: [WeeklySchedule] = [],
        evidenceLog: [EvidenceLogEntry] = [],
        preferences: FermoPreferences,
        customPresets: [FocusPreset] = [],
        savedDraft: SavedContractDraft? = nil
    ) {
        self.blocklists = blocklists
        self.sessions = sessions
        self.schedules = schedules
        self.evidenceLog = evidenceLog
        self.preferences = preferences
        self.customPresets = customPresets
        self.savedDraft = savedDraft
    }

    public init(policy: FermoPolicy, schedules: [WeeklySchedule] = []) {
        self.init(policy: policy, schedules: schedules, preferences: FermoPreferences())
    }

    public init(
        policy: FermoPolicy,
        schedules: [WeeklySchedule] = [],
        preferences: FermoPreferences,
        customPresets: [FocusPreset] = [],
        savedDraft: SavedContractDraft? = nil
    ) {
        self.init(
            blocklists: policy.blocklists,
            sessions: policy.sessions,
            schedules: schedules,
            evidenceLog: policy.evidenceLog,
            preferences: preferences,
            customPresets: customPresets,
            savedDraft: savedDraft
        )
    }

    public var policy: FermoPolicy {
        FermoPolicy(
            blocklists: blocklists,
            sessions: sessions,
            evidenceLog: evidenceLog
        )
    }

    private enum CodingKeys: String, CodingKey {
        case blocklists
        case sessions
        case schedules
        case evidenceLog
        case preferences
        case customPresets
        case savedDraft
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.blocklists = try container.decodeIfPresent([Blocklist].self, forKey: .blocklists) ?? []
        self.sessions = try container.decodeIfPresent([FocusSession].self, forKey: .sessions) ?? []
        self.schedules = try container.decodeIfPresent([WeeklySchedule].self, forKey: .schedules) ?? []
        self.evidenceLog = try container.decodeIfPresent([EvidenceLogEntry].self, forKey: .evidenceLog) ?? []
        self.preferences = try container.decodeIfPresent(FermoPreferences.self, forKey: .preferences) ?? FermoPreferences()
        self.customPresets = try container.decodeIfPresent([FocusPreset].self, forKey: .customPresets) ?? []
        self.savedDraft = try container.decodeIfPresent(SavedContractDraft.self, forKey: .savedDraft)
    }
}

public protocol FermoStore: Sendable {
    func load() throws -> FermoSnapshot
    func save(_ snapshot: FermoSnapshot) throws
}

public final class JSONFileFermoStore: FermoStore, @unchecked Sendable {
    public static let defaultFileName = "FermoSnapshot.json"

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

    public static func defaultURL(
        appGroupIdentifier: String,
        fileName: String = JSONFileFermoStore.defaultFileName
    ) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }
}
