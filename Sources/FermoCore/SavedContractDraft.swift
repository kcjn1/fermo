import Foundation

/// A persisted, resumable Start Contract draft. Stores raw text inputs (not validated rules) so a
/// half-finished contract can be saved and reopened. `FocusContractRuleDraft` resolves/validates
/// the rules only when the contract is actually started.
public struct SavedContractDraft: Codable, Equatable, Sendable {
    public var taskTitle: String
    public var intendedOutcome: String
    public var mode: FocusMode
    public var rigor: ContractRigor
    public var requiredProof: RequiredProof
    public var durationMinutes: Int
    public var blockedDomainPatterns: [String]
    public var allowedDomainPatterns: [String]
    public var blockedApps: [AppRule]
    public var allowedApps: [AppRule]

    public init(
        taskTitle: String,
        intendedOutcome: String,
        mode: FocusMode,
        rigor: ContractRigor,
        requiredProof: RequiredProof = .markdown,
        durationMinutes: Int,
        blockedDomainPatterns: [String] = [],
        allowedDomainPatterns: [String] = [],
        blockedApps: [AppRule] = [],
        allowedApps: [AppRule] = []
    ) {
        self.taskTitle = taskTitle
        self.intendedOutcome = intendedOutcome
        self.mode = mode
        self.rigor = rigor
        self.requiredProof = requiredProof
        self.durationMinutes = durationMinutes
        self.blockedDomainPatterns = blockedDomainPatterns
        self.allowedDomainPatterns = allowedDomainPatterns
        self.blockedApps = blockedApps
        self.allowedApps = allowedApps
    }

    /// The editable rule draft this saved draft represents.
    public var ruleDraft: FocusContractRuleDraft {
        FocusContractRuleDraft(
            blockedDomainPatterns: blockedDomainPatterns,
            blockedAppRules: blockedApps.map { EditableAppRule(bundleIdentifier: $0.bundleIdentifier, displayName: $0.displayName) },
            allowedDomainPatterns: allowedDomainPatterns,
            allowedAppRules: allowedApps.map { EditableAppRule(bundleIdentifier: $0.bundleIdentifier, displayName: $0.displayName) }
        )
    }
}
