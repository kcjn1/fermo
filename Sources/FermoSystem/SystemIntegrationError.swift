import Foundation

public enum SystemIntegrationError: Error, Equatable, Sendable {
    case requiresSignedAppExtension
    case helperRegistrationUnavailable
    case helperRegistrationFailed(String)
    case helperUnregistrationFailed(String)
    case missingAppGroupContainer(String)
    case diagnosticTeardownRejected(String)
}
