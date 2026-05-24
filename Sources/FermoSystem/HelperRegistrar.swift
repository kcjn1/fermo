import Foundation

#if canImport(ServiceManagement)
import ServiceManagement
#endif

public enum HelperRegistrationStatus: String, Codable, Sendable {
    case unavailable
    case notRegistered
    case requiresApproval
    case enabled
    case notFound
}

public enum HelperServiceStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

public protocol HelperServiceClient: Sendable {
    var status: HelperServiceStatus { get }
    func register() throws
    func unregister() throws
}

public struct HelperRegistrar: Sendable {
    public static let defaultLoginItemIdentifier = "com.toolary.fermo.helper"

    public let serviceIdentifier: String

    private let serviceFactory: @Sendable (String) -> (any HelperServiceClient)?

    public init(serviceIdentifier: String = Self.defaultLoginItemIdentifier) {
        self.init(serviceIdentifier: serviceIdentifier, serviceFactory: Self.liveServiceFactory)
    }

    public init(
        serviceIdentifier: String,
        serviceFactory: @escaping @Sendable (String) -> (any HelperServiceClient)?
    ) {
        self.serviceIdentifier = serviceIdentifier
        self.serviceFactory = serviceFactory
    }

    public func status() -> HelperRegistrationStatus {
        guard let service = serviceFactory(serviceIdentifier) else {
            return .unavailable
        }

        return HelperRegistrationStatus(service.status)
    }

    public func register() throws {
        guard let service = serviceFactory(serviceIdentifier) else {
            throw SystemIntegrationError.helperRegistrationUnavailable
        }

        do {
            try service.register()
        } catch {
            throw SystemIntegrationError.helperRegistrationFailed(error.localizedDescription)
        }
    }

    public func unregister() throws {
        guard let service = serviceFactory(serviceIdentifier) else {
            throw SystemIntegrationError.helperRegistrationUnavailable
        }

        do {
            try service.unregister()
        } catch {
            throw SystemIntegrationError.helperUnregistrationFailed(error.localizedDescription)
        }
    }

    public func status(plistName: String) -> HelperRegistrationStatus {
        HelperRegistrar(serviceIdentifier: plistName, serviceFactory: serviceFactory).status()
    }

    public func register(plistName: String) throws {
        try HelperRegistrar(serviceIdentifier: plistName, serviceFactory: serviceFactory).register()
    }

    public func unregister(plistName: String) throws {
        try HelperRegistrar(serviceIdentifier: plistName, serviceFactory: serviceFactory).unregister()
    }

    public static func openSystemSettingsLoginItems() {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            SMAppService.openSystemSettingsLoginItems()
        }
        #endif
    }

    private static func liveServiceFactory(identifier: String) -> (any HelperServiceClient)? {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            return SMAppServiceClient(identifier: identifier)
        }
        #endif
        return nil
    }
}

private extension HelperRegistrationStatus {
    init(_ status: HelperServiceStatus) {
        switch status {
        case .notRegistered:
            self = .notRegistered
        case .enabled:
            self = .enabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notFound
        }
    }
}

#if canImport(ServiceManagement)
@available(macOS 13.0, *)
private struct SMAppServiceClient: HelperServiceClient, @unchecked Sendable {
    private let service: SMAppService

    init(identifier: String) {
        self.service = SMAppService.loginItem(identifier: identifier)
    }

    var status: HelperServiceStatus {
        switch service.status {
        case .notRegistered:
            return .notRegistered
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .notFound
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}
#endif
