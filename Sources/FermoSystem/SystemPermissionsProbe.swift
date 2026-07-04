import FermoCore
import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

#if canImport(ApplicationServices)
import ApplicationServices
#endif

/// Live probing and requesting of the macOS permissions that Fermo cannot infer
/// from its Network Extension or helper controllers: notifications and
/// Accessibility. Pure onboarding aggregation lives in ``OnboardingProgress``.
public struct SystemPermissionsProbe: Sendable {
    public init() {}

    // MARK: - Notifications

    public func notificationState() async -> PermissionState {
        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .satisfied
        case .denied:
            return .unavailable
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
        #else
        return .unavailable
        #endif
    }

    @discardableResult
    public func requestNotifications() async -> PermissionState {
        #if canImport(UserNotifications)
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            return granted ? .satisfied : .unavailable
        } catch {
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    // MARK: - Accessibility

    public func accessibilityState() -> PermissionState {
        #if canImport(ApplicationServices)
        return AXIsProcessTrusted() ? .satisfied : .needsApproval
        #else
        return .unavailable
        #endif
    }

    /// Ask macOS to show the Accessibility prompt. The user must still flip the
    /// switch in System Settings; this only surfaces the request.
    public func requestAccessibilityPrompt() {
        #if canImport(ApplicationServices)
        // Use the raw key string to avoid referencing the non-Sendable global
        // `kAXTrustedCheckOptionPrompt` under Swift 6 strict concurrency.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        #endif
    }
}
