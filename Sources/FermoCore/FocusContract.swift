import Foundation

public enum FocusMode: String, Codable, CaseIterable, Sendable {
    case blocklist
    case focusRoom
}

public enum ContractRigor: String, Codable, CaseIterable, Sendable {
    case soft
    case locked
    case emergency
}

/// The proof a contract asks the operator to capture when the session ends. Recorded on the
/// contract so the evidence ledger states what bar was set, and surfaced by Proof Capture.
public enum RequiredProof: String, Codable, CaseIterable, Sendable {
    case note
    case markdown
    case fileOrLink

    public var displayName: String {
        switch self {
        case .note: "Short note"
        case .markdown: "Markdown evidence"
        case .fileOrLink: "File or link"
        }
    }

    public var detail: String {
        switch self {
        case .note: "A sentence on what shipped."
        case .markdown: "A written evidence note for the ledger."
        case .fileOrLink: "Attach a file path, commit, or link."
        }
    }
}

public struct FocusContract: Codable, Equatable, Sendable {
    public var taskTitle: String
    public var intendedOutcome: String
    public var mode: FocusMode
    public var rigor: ContractRigor
    public var requiredProof: RequiredProof
    public var allowedDomains: [DomainRule]
    public var allowedApps: [AppRule]

    public init(
        taskTitle: String,
        intendedOutcome: String,
        mode: FocusMode = .blocklist,
        rigor: ContractRigor = .soft,
        requiredProof: RequiredProof = .markdown,
        allowedDomains: [DomainRule] = [],
        allowedApps: [AppRule] = []
    ) {
        self.taskTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.intendedOutcome = intendedOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = mode
        self.rigor = rigor
        self.requiredProof = requiredProof
        self.allowedDomains = allowedDomains
        self.allowedApps = allowedApps
    }

    private enum CodingKeys: String, CodingKey {
        case taskTitle, intendedOutcome, mode, rigor, requiredProof, allowedDomains, allowedApps
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // decodeIfPresent + default so sessions persisted before requiredProof still decode.
        self.init(
            taskTitle: try container.decode(String.self, forKey: .taskTitle),
            intendedOutcome: try container.decode(String.self, forKey: .intendedOutcome),
            mode: try container.decodeIfPresent(FocusMode.self, forKey: .mode) ?? .blocklist,
            rigor: try container.decodeIfPresent(ContractRigor.self, forKey: .rigor) ?? .soft,
            requiredProof: try container.decodeIfPresent(RequiredProof.self, forKey: .requiredProof) ?? .markdown,
            allowedDomains: try container.decodeIfPresent([DomainRule].self, forKey: .allowedDomains) ?? [],
            allowedApps: try container.decodeIfPresent([AppRule].self, forKey: .allowedApps) ?? []
        )
    }

    public var isFocusRoom: Bool {
        mode == .focusRoom
    }
}
