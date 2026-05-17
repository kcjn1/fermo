import Foundation

public enum SystemIntegrationError: Error, Equatable, Sendable {
    case requiresSignedAppExtension
    case helperRegistrationUnavailable
}
