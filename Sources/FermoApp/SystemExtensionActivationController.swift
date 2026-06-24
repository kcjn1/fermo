import Foundation
import OSLog

#if canImport(SystemExtensions)
import SystemExtensions
#endif

enum SystemExtensionActivationError: Error, Equatable {
    case unavailable
    case needsUserApproval
    case requiresReboot
}

@MainActor
final class SystemExtensionActivationController {
    private let extensionBundleIdentifier: String
    private let logger = Logger(subsystem: "com.toolary.fermo", category: "system-extension")

    #if canImport(SystemExtensions)
    private var pendingDelegates: [UUID: SystemExtensionActivationDelegate] = [:]
    #endif

    init(extensionBundleIdentifier: String = "com.toolary.fermo.filter") {
        self.extensionBundleIdentifier = extensionBundleIdentifier
    }

    func activate() async throws {
        #if canImport(SystemExtensions)
        let requestIdentifier = UUID()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let delegate = SystemExtensionActivationDelegate(
                continuation: continuation,
                onComplete: { [weak self] in
                    self?.pendingDelegates[requestIdentifier] = nil
                }
            )
            pendingDelegates[requestIdentifier] = delegate

            let request = OSSystemExtensionRequest.activationRequest(
                forExtensionWithIdentifier: extensionBundleIdentifier,
                queue: .main
            )
            logger.info("Submitting system extension activation request for \(self.extensionBundleIdentifier, privacy: .public)")
            request.delegate = delegate
            OSSystemExtensionManager.shared.submitRequest(request)
        }
        #else
        throw SystemExtensionActivationError.unavailable
        #endif
    }
}

#if canImport(SystemExtensions)
private final class SystemExtensionActivationDelegate: NSObject, OSSystemExtensionRequestDelegate {
    private let logger = Logger(subsystem: "com.toolary.fermo", category: "system-extension")
    private var continuation: CheckedContinuation<Void, Error>?
    private let onComplete: () -> Void

    init(
        continuation: CheckedContinuation<Void, Error>,
        onComplete: @escaping () -> Void
    ) {
        self.continuation = continuation
        self.onComplete = onComplete
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("System extension request needs user approval")
        resolve(.failure(SystemExtensionActivationError.needsUserApproval), completesRequest: false)
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension extension: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        logger.info("Replacing existing system extension")
        return .replace
    }

    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        switch result {
        case .completed:
            logger.info("System extension request completed")
            resolve(.success(()), completesRequest: true)
        case .willCompleteAfterReboot:
            logger.info("System extension request will complete after reboot")
            resolve(.failure(SystemExtensionActivationError.requiresReboot), completesRequest: true)
        @unknown default:
            logger.info("System extension request completed with unknown result")
            resolve(.success(()), completesRequest: true)
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.error("System extension request failed: \(error.localizedDescription, privacy: .public)")
        resolve(.failure(error), completesRequest: true)
    }

    private func resolve(_ result: Swift.Result<Void, Error>, completesRequest: Bool) {
        if let continuation {
            self.continuation = nil
            continuation.resume(with: result)
        }

        if completesRequest {
            onComplete()
        }
    }
}
#endif
