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

public struct FocusContract: Codable, Equatable, Sendable {
    public var taskTitle: String
    public var intendedOutcome: String
    public var mode: FocusMode
    public var rigor: ContractRigor
    public var allowedDomains: [DomainRule]
    public var allowedApps: [AppRule]

    public init(
        taskTitle: String,
        intendedOutcome: String,
        mode: FocusMode = .blocklist,
        rigor: ContractRigor = .soft,
        allowedDomains: [DomainRule] = [],
        allowedApps: [AppRule] = []
    ) {
        self.taskTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.intendedOutcome = intendedOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = mode
        self.rigor = rigor
        self.allowedDomains = allowedDomains
        self.allowedApps = allowedApps
    }

    public var isFocusRoom: Bool {
        mode == .focusRoom
    }
}
