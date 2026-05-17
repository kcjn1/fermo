import Foundation

public enum FermoValidationError: Error, Equatable, Sendable {
    case emptyDomainRule
    case invalidDomainRule(String)
    case invalidDuration
    case emptySchedule
}

public struct DomainRule: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case exactOrSubdomain
        case wildcardSubdomain
    }

    public let rawPattern: String
    public let normalizedPattern: String
    public let kind: Kind

    public init(_ pattern: String) throws {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FermoValidationError.emptyDomainRule }

        let wildcardPrefix = "*."
        let isWildcard = trimmed.lowercased().hasPrefix(wildcardPrefix)
        let valueToNormalize = isWildcard ? String(trimmed.dropFirst(wildcardPrefix.count)) : trimmed

        guard let normalized = Self.normalizeHost(valueToNormalize), Self.isPlausibleDomain(normalized) else {
            throw FermoValidationError.invalidDomainRule(pattern)
        }

        self.rawPattern = trimmed
        self.normalizedPattern = normalized
        self.kind = isWildcard ? .wildcardSubdomain : .exactOrSubdomain
    }

    public func matches(host: String) -> Bool {
        guard let normalizedHost = Self.normalizeHost(host) else { return false }

        switch kind {
        case .exactOrSubdomain:
            return normalizedHost == normalizedPattern || normalizedHost.hasSuffix(".\(normalizedPattern)")
        case .wildcardSubdomain:
            return normalizedHost != normalizedPattern && normalizedHost.hasSuffix(".\(normalizedPattern)")
        }
    }

    public static func normalizeHost(_ input: String) -> String? {
        var candidate = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !candidate.isEmpty else { return nil }

        if candidate.contains("://"), let url = URL(string: candidate), let host = url.host {
            candidate = host
        } else if let slashIndex = candidate.firstIndex(of: "/") {
            candidate = String(candidate[..<slashIndex])
        }

        if let colonIndex = candidate.firstIndex(of: ":") {
            candidate = String(candidate[..<colonIndex])
        }

        candidate = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !candidate.isEmpty else { return nil }
        return candidate
    }

    private static func isPlausibleDomain(_ domain: String) -> Bool {
        guard domain.contains("."), !domain.contains("..") else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        return domain.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
