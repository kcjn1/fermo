import Foundation

/// A macOS permission Fermo asks for during first-run onboarding.
public enum PermissionKind: String, CaseIterable, Codable, Sendable {
    /// Network Extension content filter (system extension + filter configuration).
    /// Required for blocking websites across every browser.
    case websiteFilter
    /// Login Item / helper registration, so protection survives quit and login.
    case loginItem
    /// User notifications for session and degraded-protection alerts.
    case notifications
    /// Accessibility / Automation, reserved for stronger future app enforcement.
    case accessibility

    public var isRequired: Bool {
        switch self {
        case .websiteFilter: return true
        case .loginItem, .notifications, .accessibility: return false
        }
    }

    public var title: String {
        switch self {
        case .websiteFilter: return "Website filter"
        case .loginItem: return "Keep protection running"
        case .notifications: return "Notifications"
        case .accessibility: return "App control"
        }
    }
}

/// Where a single permission currently stands.
public enum PermissionState: String, Codable, Sendable {
    /// Not yet requested / unknown.
    case notDetermined
    /// Requested; user must still approve in System Settings.
    case needsApproval
    /// Granted and usable.
    case satisfied
    /// Explicitly denied or unavailable on this Mac.
    case unavailable

    public var isSatisfied: Bool { self == .satisfied }
}

public struct PermissionStatus: Equatable, Codable, Sendable {
    public var kind: PermissionKind
    public var state: PermissionState

    public init(kind: PermissionKind, state: PermissionState) {
        self.kind = kind
        self.state = state
    }
}

/// Aggregates the individual permission states into onboarding-level decisions.
public struct OnboardingProgress: Equatable, Sendable {
    public var statuses: [PermissionStatus]

    public init(statuses: [PermissionStatus]) {
        self.statuses = statuses
    }

    public func state(for kind: PermissionKind) -> PermissionState {
        statuses.first { $0.kind == kind }?.state ?? .notDetermined
    }

    /// Every required permission is granted; blocking can be trusted to work.
    public var isReady: Bool {
        PermissionKind.allCases
            .filter(\.isRequired)
            .allSatisfy { state(for: $0).isSatisfied }
    }

    /// Every permission (required and optional) is granted.
    public var isFullyGranted: Bool {
        PermissionKind.allCases.allSatisfy { state(for: $0).isSatisfied }
    }

    public var satisfiedCount: Int {
        statuses.filter { $0.state.isSatisfied }.count
    }

    public var totalCount: Int {
        PermissionKind.allCases.count
    }
}
