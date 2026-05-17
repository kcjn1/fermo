import FermoCore
import Foundation

#if canImport(NetworkExtension)
import NetworkExtension
#endif

public enum WebsiteBlockingStatus: String, Codable, Sendable {
    case unavailable
    case needsPermission
    case ready
    case active
}

public protocol WebsiteBlockingControlling: Sendable {
    func status() async -> WebsiteBlockingStatus
    func activate(policy: FermoPolicy) async throws
    func deactivate() async throws
}

public struct NetworkExtensionWebsiteBlockingController: WebsiteBlockingControlling {
    public init() {}

    public func status() async -> WebsiteBlockingStatus {
        .needsPermission
    }

    public func activate(policy: FermoPolicy) async throws {
        _ = policy
        throw SystemIntegrationError.requiresSignedAppExtension
    }

    public func deactivate() async throws {}
}
