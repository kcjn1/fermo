public enum SystemExtensionApprovalTone: Equatable, Sendable {
    case ok
    case warning
    case muted
}

public enum SystemExtensionApprovalStatus: Equatable, Sendable {
    case notRequested
    case requested
    case needsUserApproval
    case requiresReboot
    case ready
    case failed(String)

    public var displayName: String {
        switch self {
        case .notRequested:
            return "not requested"
        case .requested:
            return "request submitted"
        case .needsUserApproval:
            return "needs approval"
        case .requiresReboot:
            return "requires reboot"
        case .ready:
            return "ready"
        case .failed:
            return "failed"
        }
    }

    public var detail: String {
        switch self {
        case .notRequested:
            return "Activation request has not been submitted yet."
        case .requested:
            return "Activation request was submitted to macOS."
        case .needsUserApproval:
            return "Approve the system extension in System Settings."
        case .requiresReboot:
            return "macOS will complete activation after reboot."
        case .ready:
            return "macOS accepted the activation request."
        case .failed(let message):
            return message
        }
    }

    public var startSummary: String {
        switch self {
        case .notRequested:
            return "App Guard approval has not been requested yet."
        case .requested:
            return "App Guard approval request was submitted to macOS."
        case .needsUserApproval:
            return "Approve App Guard in System Settings to enable app launch blocking."
        case .requiresReboot:
            return "Reboot macOS to finish App Guard approval."
        case .ready:
            return "App Guard approval is ready."
        case .failed(let message):
            return "App Guard approval failed: \(message)"
        }
    }

    public var tone: SystemExtensionApprovalTone {
        switch self {
        case .ready:
            return .ok
        case .requested:
            return .muted
        case .notRequested, .needsUserApproval, .requiresReboot, .failed:
            return .warning
        }
    }
}
