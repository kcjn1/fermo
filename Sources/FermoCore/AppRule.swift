import Foundation

public struct AppRule: Codable, Equatable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Canonical form used for identity and enforcement matching. Bundle identifiers are
    /// conventionally case-insensitive, so `com.hnc.Discord` and `com.hnc.discord` are the
    /// same app. Display name is deliberately excluded from identity so the same app under
    /// two labels collapses, mirroring how `DomainRule` keys dedup on its normalized pattern.
    public var normalizedBundleIdentifier: String {
        bundleIdentifier.lowercased()
    }

    public static func == (lhs: AppRule, rhs: AppRule) -> Bool {
        lhs.normalizedBundleIdentifier == rhs.normalizedBundleIdentifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(normalizedBundleIdentifier)
    }
}
