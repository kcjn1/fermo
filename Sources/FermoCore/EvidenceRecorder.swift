import Foundation

public enum EvidenceRecordError: Error, Equatable, Sendable {
    case missingProof
    case missingNotDoneReason
    case missingBreakGlassReason
    case lockedSessionStillActive(until: Date)
    case sessionNotFound(UUID)
}

public struct EvidenceDraft: Equatable, Sendable {
    public var outcome: EvidenceOutcome
    public var note: String
    public var filePath: String
    public var commitHash: String
    public var screenshotPath: String
    public var notDoneReason: String
    public var breakGlassReason: String
    public var nextStep: String

    public init(
        outcome: EvidenceOutcome,
        note: String = "",
        filePath: String = "",
        commitHash: String = "",
        screenshotPath: String = "",
        notDoneReason: String = "",
        breakGlassReason: String = "",
        nextStep: String = ""
    ) {
        self.outcome = outcome
        self.note = note
        self.filePath = filePath
        self.commitHash = commitHash
        self.screenshotPath = screenshotPath
        self.notDoneReason = notDoneReason
        self.breakGlassReason = breakGlassReason
        self.nextStep = nextStep
    }
}

public struct EvidenceRecorder: Sendable {
    public init() {}

    public func record(
        _ draft: EvidenceDraft,
        for sessionID: UUID,
        in policy: FermoPolicy,
        at endedAt: Date = Date()
    ) throws -> FermoPolicy {
        guard let session = policy.sessions.first(where: { $0.id == sessionID }) else {
            throw EvidenceRecordError.sessionNotFound(sessionID)
        }

        let artifacts = try artifacts(from: draft, session: session, endedAt: endedAt)
        let blocklists = policy.blocklists.filter { session.blocklistIDs.contains($0.id) }
        let contract = session.contract
        let entry = EvidenceLogEntry(
            sessionID: session.id,
            createdAt: endedAt,
            taskTitle: contract?.taskTitle ?? session.title,
            intendedOutcome: contract?.intendedOutcome ?? "",
            outcome: draft.outcome,
            mode: contract?.mode ?? .blocklist,
            rigor: session.rigor,
            startedAt: session.startsAt,
            endedAt: endedAt,
            blockedDomains: blocklists.flatMap { $0.domainRules.map(\.normalizedPattern) },
            blockedApps: blocklists.flatMap { $0.appRules.map(\.bundleIdentifier) },
            allowedDomains: contract?.allowedDomains.map(\.normalizedPattern) ?? [],
            allowedApps: contract?.allowedApps.map(\.bundleIdentifier) ?? [],
            artifacts: artifacts,
            nextStep: trimmedOptional(draft.nextStep)
        )

        var nextPolicy = policy
        nextPolicy.sessions = policy.sessions.map { existing in
            guard existing.id == session.id else { return existing }
            if draft.outcome == .breakGlass {
                var cancelled = existing
                cancelled.state = .cancelled
                return cancelled
            }
            return existing.completed()
        }
        nextPolicy.evidenceLog.append(entry)
        return nextPolicy
    }

    private func artifacts(
        from draft: EvidenceDraft,
        session: FocusSession,
        endedAt: Date
    ) throws -> [EvidenceArtifact] {
        let breakGlassReason = trimmedOptional(draft.breakGlassReason)
        if session.isActive(at: endedAt), session.rigor != .soft, breakGlassReason == nil {
            throw EvidenceRecordError.lockedSessionStillActive(until: session.endsAt)
        }

        if draft.outcome == .breakGlass, breakGlassReason == nil {
            throw EvidenceRecordError.missingBreakGlassReason
        }

        let notDoneReason = trimmedOptional(draft.notDoneReason)
        if draft.outcome == .notCompleted, notDoneReason == nil, breakGlassReason == nil {
            throw EvidenceRecordError.missingNotDoneReason
        }

        var artifacts: [EvidenceArtifact] = []
        if let value = trimmedOptional(draft.note) {
            artifacts.append(.note(value))
        }
        if let value = trimmedOptional(draft.filePath) {
            artifacts.append(.filePath(value))
        }
        if let value = trimmedOptional(draft.commitHash) {
            artifacts.append(.commitHash(value))
        }
        if let value = trimmedOptional(draft.screenshotPath) {
            artifacts.append(.screenshotPath(value))
        }
        if let value = notDoneReason {
            artifacts.append(.notDoneReason(value))
        }
        if let value = breakGlassReason {
            artifacts.append(.breakGlassReason(value))
        }

        if artifacts.isEmpty {
            throw EvidenceRecordError.missingProof
        }

        return artifacts
    }

    private func trimmedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
