import FermoCore
import Foundation

public struct AppLaunchContext: Equatable, Sendable {
    public let bundleIdentifier: String?
    public let executablePath: String?

    public init(bundleIdentifier: String?, executablePath: String? = nil) {
        let trimmedIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bundleIdentifier = trimmedIdentifier?.isEmpty == true ? nil : trimmedIdentifier

        let trimmedPath = executablePath?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.executablePath = trimmedPath?.isEmpty == true ? nil : trimmedPath
    }
}

public enum AppEnforcementAllowReason: String, Equatable, Sendable {
    case noActiveSession
    case missingBundleIdentifier
    case criticalSystemApp
    case focusRoomAllowlist
    case notBlocked
}

public enum AppEnforcementDenyReason: String, Equatable, Sendable {
    case blockedByBlocklist
    case notInFocusRoomAllowlist
}

public enum AppEnforcementDecision: Equatable, Sendable {
    case allow(reason: AppEnforcementAllowReason)
    case deny(reason: AppEnforcementDenyReason)

    public var shouldAllowLaunch: Bool {
        switch self {
        case .allow:
            true
        case .deny:
            false
        }
    }

    public var shouldCacheEndpointSecurityResponse: Bool {
        false
    }
}

public protocol AppEnforcementControlling: Sendable {
    func decision(for context: AppLaunchContext, policy: FermoPolicy, at date: Date) -> AppEnforcementDecision
}

public struct AppEnforcementPolicy: AppEnforcementControlling {
    public let alwaysAllowedBundleIdentifiers: Set<String>

    public init(
        alwaysAllowedBundleIdentifiers: Set<String> = AppInterruptionController.defaultFocusRoomExcludedBundleIdentifiers
    ) {
        // Stored canonical (lowercased) so the case-insensitive lookup in `decision(for:)`
        // matches regardless of how the critical-app identifiers were cased upstream.
        self.alwaysAllowedBundleIdentifiers = Set(
            AppInterruptionController.normalizedBundleIdentifiers(alwaysAllowedBundleIdentifiers)
                .map { $0.lowercased() }
        )
    }

    public func decision(
        for context: AppLaunchContext,
        policy: FermoPolicy,
        at date: Date = Date()
    ) -> AppEnforcementDecision {
        guard !policy.activeSessions(at: date).isEmpty else {
            return .allow(reason: .noActiveSession)
        }

        guard let bundleIdentifier = context.bundleIdentifier else {
            // A Focus Room is allowlist-only, so an app we cannot identify must not slip
            // through. A blocklist cannot match an unknown identifier, so allow it there.
            let hasActiveFocusRoom = policy.activeSessions(at: date).contains { $0.contract?.isFocusRoom == true }
            return hasActiveFocusRoom
                ? .deny(reason: .notInFocusRoomAllowlist)
                : .allow(reason: .missingBundleIdentifier)
        }

        // Bundle identifiers are conventionally case-insensitive; match on the canonical
        // (lowercased) form so policy authored in any casing enforces consistently.
        let normalizedBundleIdentifier = bundleIdentifier.lowercased()

        if alwaysAllowedBundleIdentifiers.contains(normalizedBundleIdentifier) {
            return .allow(reason: .criticalSystemApp)
        }

        if policy.blockedAppBundleIdentifiers(at: date).contains(where: { $0.lowercased() == normalizedBundleIdentifier }) {
            return .deny(reason: .blockedByBlocklist)
        }

        let hasActiveFocusRoom = policy.activeSessions(at: date).contains { $0.contract?.isFocusRoom == true }
        if hasActiveFocusRoom {
            return policy.isAppAllowedInFocusRoom(bundleIdentifier: bundleIdentifier, at: date)
                ? .allow(reason: .focusRoomAllowlist)
                : .deny(reason: .notInFocusRoomAllowlist)
        }

        return .allow(reason: .notBlocked)
    }
}
