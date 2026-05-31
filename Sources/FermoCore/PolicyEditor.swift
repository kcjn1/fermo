import Foundation

public struct EditableAppRule: Equatable, Sendable {
    public var bundleIdentifier: String
    public var displayName: String

    public init(bundleIdentifier: String, displayName: String = "") {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
}

public struct BlocklistEditorDraft: Equatable, Sendable {
    public var name: String
    public var domainPatterns: [String]
    public var appRules: [EditableAppRule]
    public var isEnabled: Bool

    public init(
        name: String,
        domainPatterns: [String] = [],
        appRules: [EditableAppRule] = [],
        isEnabled: Bool = true
    ) {
        self.name = name
        self.domainPatterns = domainPatterns
        self.appRules = appRules
        self.isEnabled = isEnabled
    }

    public init(blocklist: Blocklist) {
        self.init(
            name: blocklist.name,
            domainPatterns: blocklist.domainRules.map(\.rawPattern),
            appRules: blocklist.appRules.map {
                EditableAppRule(bundleIdentifier: $0.bundleIdentifier, displayName: $0.displayName)
            },
            isEnabled: blocklist.isEnabled
        )
    }
}

public enum PolicyEditorError: Error, Equatable, Sendable {
    case emptyBlocklistName
    case blocklistNotFound(UUID)
    case emptyAppBundleIdentifier
}

public struct PolicyEditor: Sendable {
    private let lockedModeGuard: LockedModeGuard

    public init(lockedModeGuard: LockedModeGuard = LockedModeGuard()) {
        self.lockedModeGuard = lockedModeGuard
    }

    public func addBlocklist(
        _ draft: BlocklistEditorDraft,
        to policy: FermoPolicy,
        at date: Date = Date()
    ) throws -> FermoPolicy {
        try lockedModeGuard.validate(.editSessionBlocklists, for: policy, at: date)

        var nextPolicy = policy
        nextPolicy.blocklists.append(try makeBlocklist(from: draft))
        return nextPolicy
    }

    public func updateBlocklist(
        id: UUID,
        with draft: BlocklistEditorDraft,
        in policy: FermoPolicy,
        at date: Date = Date()
    ) throws -> FermoPolicy {
        try lockedModeGuard.validate(.editSessionBlocklists, for: policy, at: date)

        guard let index = policy.blocklists.firstIndex(where: { $0.id == id }) else {
            throw PolicyEditorError.blocklistNotFound(id)
        }

        var nextPolicy = policy
        nextPolicy.blocklists[index] = try makeBlocklist(id: id, from: draft)
        return nextPolicy
    }

    public func deleteBlocklist(
        id: UUID,
        from policy: FermoPolicy,
        at date: Date = Date()
    ) throws -> FermoPolicy {
        try lockedModeGuard.validate(.deleteProtectedBlocklist, for: policy, at: date)

        guard policy.blocklists.contains(where: { $0.id == id }) else {
            throw PolicyEditorError.blocklistNotFound(id)
        }

        var nextPolicy = policy
        nextPolicy.blocklists.removeAll { $0.id == id }
        nextPolicy.sessions = policy.sessions.map { session in
            var nextSession = session
            nextSession.blocklistIDs.removeAll { $0 == id }
            return nextSession
        }
        return nextPolicy
    }

    private func makeBlocklist(id: UUID = UUID(), from draft: BlocklistEditorDraft) throws -> Blocklist {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw PolicyEditorError.emptyBlocklistName
        }

        let domains = try draft.domainPatterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(DomainRule.init)
            .deduplicatedByNormalizedPattern()

        let apps = try draft.appRules.compactMap { editable -> AppRule? in
            let bundleIdentifier = editable.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = editable.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

            if bundleIdentifier.isEmpty && displayName.isEmpty {
                return nil
            }

            guard !bundleIdentifier.isEmpty else {
                throw PolicyEditorError.emptyAppBundleIdentifier
            }

            return AppRule(
                bundleIdentifier: bundleIdentifier,
                displayName: displayName.isEmpty ? bundleIdentifier : displayName
            )
        }
        .deduplicated()

        return Blocklist(
            id: id,
            name: name,
            domainRules: domains,
            appRules: apps,
            isEnabled: draft.isEnabled
        )
    }
}

private extension Array where Element: Hashable {
    func deduplicated() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
