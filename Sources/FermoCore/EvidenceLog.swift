import Foundation

public enum EvidenceOutcome: String, Codable, CaseIterable, Sendable {
    case completed
    case partiallyCompleted
    case notCompleted
    case breakGlass
}

public enum EvidenceArtifact: Codable, Equatable, Sendable {
    case note(String)
    case filePath(String)
    case commitHash(String)
    case screenshotPath(String)
    case notDoneReason(String)
    case breakGlassReason(String)
}

public struct EvidenceLogEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var sessionID: UUID
    public var createdAt: Date
    public var taskTitle: String
    public var intendedOutcome: String
    public var outcome: EvidenceOutcome
    public var mode: FocusMode
    public var rigor: ContractRigor
    public var startedAt: Date
    public var endedAt: Date
    public var blockedDomains: [String]
    public var blockedApps: [String]
    public var allowedDomains: [String]
    public var allowedApps: [String]
    public var artifacts: [EvidenceArtifact]
    public var nextStep: String?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        createdAt: Date = Date(),
        taskTitle: String,
        intendedOutcome: String,
        outcome: EvidenceOutcome,
        mode: FocusMode,
        rigor: ContractRigor,
        startedAt: Date,
        endedAt: Date,
        blockedDomains: [String],
        blockedApps: [String],
        allowedDomains: [String] = [],
        allowedApps: [String] = [],
        artifacts: [EvidenceArtifact],
        nextStep: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.taskTitle = taskTitle
        self.intendedOutcome = intendedOutcome
        self.outcome = outcome
        self.mode = mode
        self.rigor = rigor
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.blockedDomains = blockedDomains
        self.blockedApps = blockedApps
        self.allowedDomains = allowedDomains
        self.allowedApps = allowedApps
        self.artifacts = artifacts
        self.nextStep = nextStep
    }
}

public struct EvidenceMarkdownRenderer: Sendable {
    public init() {}

    public func render(_ entry: EvidenceLogEntry) -> String {
        var lines: [String] = [
            "# \(entry.taskTitle)",
            "",
            "- Session ID: `\(entry.sessionID.uuidString)`",
            "- Created: \(entry.createdAt.formattedISO8601)",
            "- Started: \(entry.startedAt.formattedISO8601)",
            "- Ended: \(entry.endedAt.formattedISO8601)",
            "- Outcome: \(entry.outcome.rawValue)",
            "- Mode: \(entry.mode.rawValue)",
            "- Rigor: \(entry.rigor.rawValue)",
            "",
            "## Intended Outcome",
            "",
            entry.intendedOutcome,
            "",
            "## Proof",
            ""
        ]

        if entry.artifacts.isEmpty {
            lines.append("- No proof recorded.")
        } else {
            lines.append(contentsOf: entry.artifacts.map(Self.renderArtifact))
        }

        lines.append(contentsOf: [
            "",
            "## Focus Room",
            "",
            "### Allowed Domains",
            ""
        ])
        lines.append(contentsOf: Self.renderList(entry.allowedDomains))
        lines.append(contentsOf: [
            "",
            "### Allowed Apps",
            ""
        ])
        lines.append(contentsOf: Self.renderList(entry.allowedApps))
        lines.append(contentsOf: [
            "",
            "## Blocks",
            "",
            "### Blocked Domains",
            ""
        ])
        lines.append(contentsOf: Self.renderList(entry.blockedDomains))
        lines.append(contentsOf: [
            "",
            "### Blocked Apps",
            ""
        ])
        lines.append(contentsOf: Self.renderList(entry.blockedApps))

        if let nextStep = entry.nextStep?.trimmingCharacters(in: .whitespacesAndNewlines), !nextStep.isEmpty {
            lines.append(contentsOf: [
                "",
                "## Next Step",
                "",
                nextStep
            ])
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Render an entire evidence ledger as a single Markdown document, newest first.
    public func renderLedger(_ entries: [EvidenceLogEntry]) -> String {
        guard !entries.isEmpty else {
            return "# Fermo Evidence Ledger\n\nNo proof recorded yet.\n"
        }

        let ordered = entries.sorted { $0.endedAt > $1.endedAt }
        var document = "# Fermo Evidence Ledger\n\n\(ordered.count) recorded sessions.\n"
        for entry in ordered {
            document += "\n---\n\n"
            document += render(entry)
        }
        return document
    }

    private static func renderArtifact(_ artifact: EvidenceArtifact) -> String {
        switch artifact {
        case .note(let value):
            return "- Note: \(value)"
        case .filePath(let value):
            return "- File: `\(value)`"
        case .commitHash(let value):
            return "- Commit: `\(value)`"
        case .screenshotPath(let value):
            return "- Screenshot: `\(value)`"
        case .notDoneReason(let value):
            return "- Not done: \(value)"
        case .breakGlassReason(let value):
            return "- Break glass: \(value)"
        }
    }

    private static func renderList(_ items: [String]) -> [String] {
        items.isEmpty ? ["- None recorded."] : items.sorted().map { "- `\($0)`" }
    }
}

private extension Date {
    var formattedISO8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}
