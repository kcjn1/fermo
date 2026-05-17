import Foundation

#if canImport(ServiceManagement)
import ServiceManagement
#endif

public enum HelperRegistrationStatus: String, Codable, Sendable {
    case unavailable
    case notRegistered
    case requiresApproval
    case enabled
}

public struct HelperRegistrar: Sendable {
    public init() {}

    public func status(plistName: String) -> HelperRegistrationStatus {
        _ = plistName
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            return .notRegistered
        }
        #endif
        return .unavailable
    }

    public func register(plistName: String) throws {
        _ = plistName
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            throw SystemIntegrationError.helperRegistrationUnavailable
        }
        #endif
        throw SystemIntegrationError.helperRegistrationUnavailable
    }
}
