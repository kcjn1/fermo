import FermoSystem
import Foundation
import Testing

@Test
func helperRegistrarMapsServiceStatuses() {
    let cases: [(HelperServiceStatus, HelperRegistrationStatus)] = [
        (.notRegistered, .notRegistered),
        (.enabled, .enabled),
        (.requiresApproval, .requiresApproval),
        (.notFound, .notFound)
    ]

    for (serviceStatus, expectedStatus) in cases {
        let service = FakeHelperService(status: serviceStatus)
        let registrar = HelperRegistrar(serviceIdentifier: "com.toolary.fermo.helper") { _ in service }

        #expect(registrar.status() == expectedStatus)
    }
}

@Test
func helperRegistrarReportsUnavailableWithoutServiceManagementClient() {
    let registrar = HelperRegistrar(serviceIdentifier: "com.toolary.fermo.helper") { _ in nil }

    #expect(registrar.status() == .unavailable)
    #expect(throws: SystemIntegrationError.helperRegistrationUnavailable) {
        try registrar.register()
    }
    #expect(throws: SystemIntegrationError.helperRegistrationUnavailable) {
        try registrar.unregister()
    }
}

@Test
func helperRegistrarCallsRegisterAndUnregister() throws {
    let service = FakeHelperService(status: .notRegistered)
    let registrar = HelperRegistrar(serviceIdentifier: "com.toolary.fermo.helper") { identifier in
        #expect(identifier == "com.toolary.fermo.helper")
        return service
    }

    try registrar.register()
    try registrar.unregister()

    #expect(service.registerCallCount == 1)
    #expect(service.unregisterCallCount == 1)
}

@Test
func helperRegistrarWrapsRegistrationErrors() {
    let service = FakeHelperService(
        status: .notRegistered,
        registerError: FakeError(description: "launch denied by user")
    )
    let registrar = HelperRegistrar(serviceIdentifier: "com.toolary.fermo.helper") { _ in service }

    #expect(throws: SystemIntegrationError.helperRegistrationFailed("launch denied by user")) {
        try registrar.register()
    }
}

@Test
func helperRegistrarWrapsUnregistrationErrors() {
    let service = FakeHelperService(
        status: .enabled,
        unregisterError: FakeError(description: "job not found")
    )
    let registrar = HelperRegistrar(serviceIdentifier: "com.toolary.fermo.helper") { _ in service }

    #expect(throws: SystemIntegrationError.helperUnregistrationFailed("job not found")) {
        try registrar.unregister()
    }
}

private final class FakeHelperService: HelperServiceClient, @unchecked Sendable {
    var status: HelperServiceStatus
    var registerCallCount = 0
    var unregisterCallCount = 0

    private let registerError: (any Error)?
    private let unregisterError: (any Error)?

    init(
        status: HelperServiceStatus,
        registerError: (any Error)? = nil,
        unregisterError: (any Error)? = nil
    ) {
        self.status = status
        self.registerError = registerError
        self.unregisterError = unregisterError
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
    }
}

private struct FakeError: LocalizedError {
    let description: String

    var errorDescription: String? {
        description
    }
}
