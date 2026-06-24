public enum ProtectionOnboardingState: Equatable, Sendable {
    case ready
    case actionNeeded
    case unavailable
}

public struct ProtectionOnboardingItem: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var detail: String
    public var state: ProtectionOnboardingState

    public init(id: String, title: String, detail: String, state: ProtectionOnboardingState) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

public struct ProtectionOnboardingChecklist: Equatable, Sendable {
    public var items: [ProtectionOnboardingItem]

    public init(
        websiteBlockingStatus: WebsiteBlockingStatus,
        appGuardApprovalStatus: SystemExtensionApprovalStatus,
        helperStatus: HelperRegistrationStatus
    ) {
        self.items = [
            Self.websiteBlockingItem(status: websiteBlockingStatus),
            Self.appGuardItem(status: appGuardApprovalStatus),
            Self.helperItem(status: helperStatus)
        ]
    }

    public var overallState: ProtectionOnboardingState {
        if items.contains(where: { $0.state == .actionNeeded }) {
            return .actionNeeded
        }

        if items.contains(where: { $0.state == .unavailable }) {
            return .unavailable
        }

        return .ready
    }

    public var summary: String {
        switch overallState {
        case .ready:
            return "Runtime approvals are ready for a signed validation pass."
        case .actionNeeded:
            return "Finish macOS approvals before trusting protected sessions."
        case .unavailable:
            return "One or more runtime gates are unavailable on this Mac."
        }
    }

    private static func websiteBlockingItem(status: WebsiteBlockingStatus) -> ProtectionOnboardingItem {
        switch status {
        case .active, .ready:
            return ProtectionOnboardingItem(
                id: "website-blocking",
                title: "Website blocking approval",
                detail: "Fermo Focus Filter is approved for website rules.",
                state: .ready
            )
        case .needsPermission:
            return ProtectionOnboardingItem(
                id: "website-blocking",
                title: "Website blocking approval",
                detail: "Approve the Fermo Focus Filter before website rules can be enforced.",
                state: .actionNeeded
            )
        case .unavailable:
            return ProtectionOnboardingItem(
                id: "website-blocking",
                title: "Website blocking approval",
                detail: "Network Extension APIs are unavailable in this environment.",
                state: .unavailable
            )
        }
    }

    private static func appGuardItem(status: SystemExtensionApprovalStatus) -> ProtectionOnboardingItem {
        switch status {
        case .ready:
            return ProtectionOnboardingItem(
                id: "app-guard",
                title: "App launch approval",
                detail: "App Guard is approved for launch/relaunch enforcement.",
                state: .ready
            )
        case .failed(let message):
            return ProtectionOnboardingItem(
                id: "app-guard",
                title: "App launch approval",
                detail: "App Guard approval failed: \(message)",
                state: .actionNeeded
            )
        case .requiresReboot:
            return ProtectionOnboardingItem(
                id: "app-guard",
                title: "App launch approval",
                detail: "Reboot macOS to finish App Guard approval.",
                state: .actionNeeded
            )
        case .needsUserApproval:
            return ProtectionOnboardingItem(
                id: "app-guard",
                title: "App launch approval",
                detail: "Approve App Guard in System Settings before protected sessions can deny app relaunches.",
                state: .actionNeeded
            )
        case .requested:
            return ProtectionOnboardingItem(
                id: "app-guard",
                title: "App launch approval",
                detail: "macOS received the App Guard request. Check System Settings if approval is pending.",
                state: .actionNeeded
            )
        case .notRequested:
            return ProtectionOnboardingItem(
                id: "app-guard",
                title: "App launch approval",
                detail: "Request App Guard approval before validating app launch blocking.",
                state: .actionNeeded
            )
        }
    }

    private static func helperItem(status: HelperRegistrationStatus) -> ProtectionOnboardingItem {
        switch status {
        case .enabled:
            return ProtectionOnboardingItem(
                id: "helper",
                title: "Login item helper",
                detail: "FermoHelper is enabled for relaunch/login restore.",
                state: .ready
            )
        case .requiresApproval:
            return ProtectionOnboardingItem(
                id: "helper",
                title: "Login item helper",
                detail: "Allow the login item so active sessions can be restored after relaunch or login.",
                state: .actionNeeded
            )
        case .notRegistered:
            return ProtectionOnboardingItem(
                id: "helper",
                title: "Login item helper",
                detail: "Register FermoHelper before lifecycle validation.",
                state: .actionNeeded
            )
        case .notFound:
            return ProtectionOnboardingItem(
                id: "helper",
                title: "Login item helper",
                detail: "FermoHelper is not embedded in this app build.",
                state: .unavailable
            )
        case .unavailable:
            return ProtectionOnboardingItem(
                id: "helper",
                title: "Login item helper",
                detail: "Login item APIs are unavailable in this environment.",
                state: .unavailable
            )
        }
    }
}

