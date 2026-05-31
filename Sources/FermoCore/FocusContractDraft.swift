import Foundation

public enum FocusContractDraftError: Error, Equatable, Sendable {
    case emptyTaskTitle
    case emptyIntendedOutcome
    case missingBlockRules
    case missingFocusRoomAllowRules
}

public enum FocusContractRuleDraftError: Error, Equatable, Sendable {
    case emptyAppBundleIdentifier
}

public struct FocusContractRuleSet: Equatable, Sendable {
    public var blockedDomains: [DomainRule]
    public var blockedApps: [AppRule]
    public var allowedDomains: [DomainRule]
    public var allowedApps: [AppRule]

    public init(
        blockedDomains: [DomainRule] = [],
        blockedApps: [AppRule] = [],
        allowedDomains: [DomainRule] = [],
        allowedApps: [AppRule] = []
    ) {
        self.blockedDomains = blockedDomains
        self.blockedApps = blockedApps
        self.allowedDomains = allowedDomains
        self.allowedApps = allowedApps
    }
}

public struct FocusContractRuleDraft: Equatable, Sendable {
    public var blockedDomainPatterns: [String]
    public var blockedAppRules: [EditableAppRule]
    public var allowedDomainPatterns: [String]
    public var allowedAppRules: [EditableAppRule]

    public init(
        blockedDomainPatterns: [String] = [],
        blockedAppRules: [EditableAppRule] = [],
        allowedDomainPatterns: [String] = [],
        allowedAppRules: [EditableAppRule] = []
    ) {
        self.blockedDomainPatterns = blockedDomainPatterns
        self.blockedAppRules = blockedAppRules
        self.allowedDomainPatterns = allowedDomainPatterns
        self.allowedAppRules = allowedAppRules
    }

    public init(preset: FocusPreset) {
        self.init(
            blockedDomainPatterns: preset.blockedDomains.map(\.rawPattern),
            blockedAppRules: preset.blockedApps.map {
                EditableAppRule(bundleIdentifier: $0.bundleIdentifier, displayName: $0.displayName)
            },
            allowedDomainPatterns: preset.allowedDomains.map(\.rawPattern),
            allowedAppRules: preset.allowedApps.map {
                EditableAppRule(bundleIdentifier: $0.bundleIdentifier, displayName: $0.displayName)
            }
        )
    }

    public func resolved() throws -> FocusContractRuleSet {
        FocusContractRuleSet(
            blockedDomains: try domainRules(from: blockedDomainPatterns),
            blockedApps: try appRules(from: blockedAppRules),
            allowedDomains: try domainRules(from: allowedDomainPatterns),
            allowedApps: try appRules(from: allowedAppRules)
        )
    }

    private func domainRules(from patterns: [String]) throws -> [DomainRule] {
        try patterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(DomainRule.init)
            .deduplicatedByNormalizedPattern()
    }

    private func appRules(from rules: [EditableAppRule]) throws -> [AppRule] {
        try rules.compactMap { editable -> AppRule? in
            let bundleIdentifier = editable.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = editable.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

            if bundleIdentifier.isEmpty && displayName.isEmpty {
                return nil
            }

            guard !bundleIdentifier.isEmpty else {
                throw FocusContractRuleDraftError.emptyAppBundleIdentifier
            }

            return AppRule(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName.isEmpty ? bundleIdentifier : displayName
            )
        }
        .deduplicated()
    }
}

public struct FocusContractDraft: Equatable, Sendable {
    public var taskTitle: String
    public var intendedOutcome: String
    public var mode: FocusMode
    public var rigor: ContractRigor
    public var duration: TimeInterval
    public var blockedDomains: [DomainRule]
    public var blockedApps: [AppRule]
    public var allowedDomains: [DomainRule]
    public var allowedApps: [AppRule]

    public init(
        taskTitle: String,
        intendedOutcome: String,
        mode: FocusMode,
        rigor: ContractRigor,
        duration: TimeInterval,
        blockedDomains: [DomainRule] = [],
        blockedApps: [AppRule] = [],
        allowedDomains: [DomainRule] = [],
        allowedApps: [AppRule] = []
    ) {
        self.taskTitle = taskTitle
        self.intendedOutcome = intendedOutcome
        self.mode = mode
        self.rigor = rigor
        self.duration = duration
        self.blockedDomains = blockedDomains
        self.blockedApps = blockedApps
        self.allowedDomains = allowedDomains
        self.allowedApps = allowedApps
    }

    public init(
        preset: FocusPreset,
        taskTitle: String,
        intendedOutcome: String,
        duration: TimeInterval,
        mode: FocusMode? = nil,
        rigor: ContractRigor? = nil
    ) {
        self.init(
            taskTitle: taskTitle,
            intendedOutcome: intendedOutcome,
            mode: mode ?? preset.mode,
            rigor: rigor ?? preset.suggestedRigor,
            duration: duration,
            blockedDomains: preset.blockedDomains,
            blockedApps: preset.blockedApps,
            allowedDomains: preset.allowedDomains,
            allowedApps: preset.allowedApps
        )
    }

    public init(
        taskTitle: String,
        intendedOutcome: String,
        mode: FocusMode,
        rigor: ContractRigor,
        duration: TimeInterval,
        rules: FocusContractRuleSet
    ) {
        self.init(
            taskTitle: taskTitle,
            intendedOutcome: intendedOutcome,
            mode: mode,
            rigor: rigor,
            duration: duration,
            blockedDomains: rules.blockedDomains,
            blockedApps: rules.blockedApps,
            allowedDomains: rules.allowedDomains,
            allowedApps: rules.allowedApps
        )
    }

    public func activePolicy(startingAt startDate: Date = Date()) throws -> FermoPolicy {
        try policy(startingAt: startDate, state: .active)
    }

    public func scheduledPolicy(startingAt startDate: Date) throws -> FermoPolicy {
        try policy(startingAt: startDate, state: .scheduled)
    }

    private func policy(startingAt startDate: Date, state: FocusSessionState) throws -> FermoPolicy {
        let trimmedTask = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTask.isEmpty else { throw FocusContractDraftError.emptyTaskTitle }

        let trimmedOutcome = intendedOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutcome.isEmpty else { throw FocusContractDraftError.emptyIntendedOutcome }

        switch mode {
        case .blocklist:
            guard !blockedDomains.isEmpty || !blockedApps.isEmpty else {
                throw FocusContractDraftError.missingBlockRules
            }
        case .focusRoom:
            guard !allowedDomains.isEmpty || !allowedApps.isEmpty else {
                throw FocusContractDraftError.missingFocusRoomAllowRules
            }
        }

        let blocklist = Blocklist(
            name: "\(trimmedTask) Rules",
            domainRules: blockedDomains,
            appRules: blockedApps
        )
        let blocklistIDs = (blockedDomains.isEmpty && blockedApps.isEmpty) ? [] : [blocklist.id]
        let session = try FocusSession(
            title: trimmedTask,
            contract: FocusContract(
                taskTitle: trimmedTask,
                intendedOutcome: trimmedOutcome,
                mode: mode,
                rigor: rigor,
                allowedDomains: allowedDomains,
                allowedApps: allowedApps
            ),
            blocklistIDs: blocklistIDs,
            startsAt: startDate,
            duration: duration,
            lockedMode: rigor != .soft,
            rigor: rigor,
            state: state
        )

        return FermoPolicy(
            blocklists: blocklistIDs.isEmpty ? [] : [blocklist],
            sessions: [session]
        )
    }
}

private extension Array where Element: Hashable {
    func deduplicated() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
