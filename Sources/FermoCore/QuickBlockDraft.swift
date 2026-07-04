import Foundation

public enum QuickBlockError: Error, Equatable, Sendable {
    case emptyRoom
}

/// A fast, Freedom-style block: enforce an existing room/blocklist for a fixed
/// duration without writing a full focus contract (no task or intended outcome).
public struct QuickBlockDraft: Equatable, Sendable {
    public var blocklist: Blocklist
    public var duration: TimeInterval
    public var rigor: ContractRigor

    public init(blocklist: Blocklist, duration: TimeInterval, rigor: ContractRigor = .soft) {
        self.blocklist = blocklist
        self.duration = duration
        self.rigor = rigor
    }

    public func activePolicy(startingAt startDate: Date = Date()) throws -> FermoPolicy {
        guard !blocklist.domainRules.isEmpty || !blocklist.appRules.isEmpty else {
            throw QuickBlockError.emptyRoom
        }

        var room = blocklist
        room.isEnabled = true

        let session = try FocusSession(
            title: room.name,
            contract: nil,
            blocklistIDs: [room.id],
            startsAt: startDate,
            duration: duration,
            lockedMode: rigor != .soft,
            rigor: rigor,
            state: .active
        )

        return FermoPolicy(blocklists: [room], sessions: [session])
    }
}

public extension FocusPreset {
    /// A reusable ``Blocklist`` derived from this preset's blocked rules, suitable
    /// for Quick Block. Focus Room allow-lists are intentionally ignored here:
    /// Quick Block is a blunt blocklist, not a room.
    func asBlocklist() -> Blocklist {
        Blocklist(
            name: name,
            domainRules: blockedDomains,
            appRules: blockedApps
        )
    }
}
