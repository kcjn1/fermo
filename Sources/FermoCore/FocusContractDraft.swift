import Foundation

public enum FocusContractDraftError: Error, Equatable, Sendable {
    case emptyTaskTitle
    case emptyIntendedOutcome
    case missingBlockRules
    case missingFocusRoomAllowRules
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

    public func activePolicy(startingAt startDate: Date = Date()) throws -> FermoPolicy {
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
            state: .active
        )

        return FermoPolicy(
            blocklists: blocklistIDs.isEmpty ? [] : [blocklist],
            sessions: [session]
        )
    }
}
