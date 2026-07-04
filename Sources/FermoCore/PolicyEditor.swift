import Foundation

public enum PolicyEditError: Error, Equatable, Sendable {
    case blocklistNotFound(UUID)
    case duplicateDomain(String)
    case duplicateApp(String)
    case emptyName
}

/// Testable, side-effect-free editing of a ``FermoPolicy``'s rooms/blocklists.
///
/// Strengthening edits (adding a blocked domain or app, creating or enabling a
/// blocklist) are always allowed. Weakening edits (removing a rule, disabling or
/// deleting a blocklist) are routed through ``LockedModeGuard`` so that an active
/// Locked or Emergency contract cannot be quietly weakened.
public struct PolicyEditor: Sendable {
    private let lockedModeGuard: LockedModeGuard

    public init(lockedModeGuard: LockedModeGuard = LockedModeGuard()) {
        self.lockedModeGuard = lockedModeGuard
    }

    // MARK: - Blocklist lifecycle

    public func createBlocklist(named name: String, in policy: FermoPolicy) throws -> FermoPolicy {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PolicyEditError.emptyName }
        var next = policy
        next.blocklists.append(Blocklist(name: trimmed))
        return next
    }

    public func renameBlocklist(_ id: UUID, to name: String, in policy: FermoPolicy) throws -> FermoPolicy {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PolicyEditError.emptyName }
        var next = policy
        try mutateBlocklist(id, in: &next) { $0.name = trimmed }
        return next
    }

    public func setBlocklist(_ id: UUID, enabled: Bool, in policy: FermoPolicy, at date: Date = Date()) throws -> FermoPolicy {
        if !enabled {
            try lockedModeGuard.validate(.editSessionBlocklists, for: policy, at: date)
        }
        var next = policy
        try mutateBlocklist(id, in: &next) { $0.isEnabled = enabled }
        return next
    }

    public func deleteBlocklist(_ id: UUID, in policy: FermoPolicy, at date: Date = Date()) throws -> FermoPolicy {
        try lockedModeGuard.validate(.deleteProtectedBlocklist, for: policy, at: date)
        guard policy.blocklists.contains(where: { $0.id == id }) else {
            throw PolicyEditError.blocklistNotFound(id)
        }
        var next = policy
        next.blocklists.removeAll { $0.id == id }
        return next
    }

    // MARK: - Domain rules

    public func addDomain(_ pattern: String, to blocklistID: UUID, in policy: FermoPolicy) throws -> FermoPolicy {
        let rule = try DomainRule(pattern)
        var next = policy
        try mutateBlocklist(blocklistID, in: &next) { blocklist in
            guard !blocklist.domainRules.contains(where: { $0.normalizedPattern == rule.normalizedPattern }) else {
                throw PolicyEditError.duplicateDomain(rule.normalizedPattern)
            }
            blocklist.domainRules.append(rule)
        }
        return next
    }

    public func removeDomain(
        normalizedPattern: String,
        from blocklistID: UUID,
        in policy: FermoPolicy,
        at date: Date = Date()
    ) throws -> FermoPolicy {
        try lockedModeGuard.validate(.editSessionBlocklists, for: policy, at: date)
        var next = policy
        try mutateBlocklist(blocklistID, in: &next) { blocklist in
            blocklist.domainRules.removeAll { $0.normalizedPattern == normalizedPattern }
        }
        return next
    }

    // MARK: - App rules

    public func addApp(_ rule: AppRule, to blocklistID: UUID, in policy: FermoPolicy) throws -> FermoPolicy {
        var next = policy
        try mutateBlocklist(blocklistID, in: &next) { blocklist in
            guard !blocklist.appRules.contains(where: { $0.bundleIdentifier == rule.bundleIdentifier }) else {
                throw PolicyEditError.duplicateApp(rule.bundleIdentifier)
            }
            blocklist.appRules.append(rule)
        }
        return next
    }

    public func removeApp(
        bundleIdentifier: String,
        from blocklistID: UUID,
        in policy: FermoPolicy,
        at date: Date = Date()
    ) throws -> FermoPolicy {
        try lockedModeGuard.validate(.editSessionBlocklists, for: policy, at: date)
        var next = policy
        try mutateBlocklist(blocklistID, in: &next) { blocklist in
            blocklist.appRules.removeAll { $0.bundleIdentifier == bundleIdentifier }
        }
        return next
    }

    // MARK: - Helpers

    private func mutateBlocklist(
        _ id: UUID,
        in policy: inout FermoPolicy,
        _ body: (inout Blocklist) throws -> Void
    ) throws {
        guard let index = policy.blocklists.firstIndex(where: { $0.id == id }) else {
            throw PolicyEditError.blocklistNotFound(id)
        }
        try body(&policy.blocklists[index])
    }
}
