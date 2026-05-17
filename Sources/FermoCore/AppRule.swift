import Foundation

public struct AppRule: Codable, Equatable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
