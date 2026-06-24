import EndpointSecurity
import FermoSystem
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.toolary.fermo.appguard", category: "endpoint-security")

private final class FermoAppGuardEndpointSecurityService {
    private let policyStore: AppGuardPolicyStore
    private var client: OpaquePointer?

    init(policyStore: AppGuardPolicyStore) {
        self.policyStore = policyStore
    }

    func start() -> es_new_client_result_t {
        let result = es_new_client(&client) { [policyStore] client, message in
            guard message.pointee.event_type == ES_EVENT_TYPE_AUTH_EXEC else {
                return
            }

            let context = Self.launchContext(from: message)
            let decision: AppEnforcementDecision
            do {
                decision = try policyStore.decision(for: context, at: Date())
            } catch {
                logger.error("Could not load Fermo policy for app launch decision: \(error.localizedDescription, privacy: .public)")
                es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, false)
                return
            }

            switch decision {
            case .allow(let reason):
                logger.debug("Allowing launch for \(context.bundleIdentifier ?? "unknown", privacy: .public): \(reason.rawValue, privacy: .public)")
                es_respond_auth_result(
                    client,
                    message,
                    ES_AUTH_RESULT_ALLOW,
                    decision.shouldCacheEndpointSecurityResponse
                )
            case .deny(let reason):
                logger.info("Denying launch for \(context.bundleIdentifier ?? "unknown", privacy: .public): \(reason.rawValue, privacy: .public)")
                es_respond_auth_result(
                    client,
                    message,
                    ES_AUTH_RESULT_DENY,
                    decision.shouldCacheEndpointSecurityResponse
                )
            }
        }

        guard result == ES_NEW_CLIENT_RESULT_SUCCESS, let client else {
            return result
        }

        let events = [ES_EVENT_TYPE_AUTH_EXEC]
        let subscribeResult = events.withUnsafeBufferPointer { buffer in
            es_subscribe(client, buffer.baseAddress!, UInt32(buffer.count))
        }

        if subscribeResult != ES_RETURN_SUCCESS {
            logger.error("Endpoint Security subscription failed with code \(subscribeResult.rawValue, privacy: .public)")
        }

        return result
    }

    deinit {
        if let client {
            es_delete_client(client)
        }
    }

    private static func launchContext(from message: UnsafePointer<es_message_t>) -> AppLaunchContext {
        let process = message.pointee.event.exec.target.pointee
        let executablePath = string(from: process.executable.pointee.path)
        let signingIdentifier = string(from: process.signing_id)

        // Fermo policy is keyed on CFBundleIdentifier, which is not the same as the
        // code-signing signing_id. Resolve the real bundle id from the executable's
        // enclosing .app, and only fall back to signing_id when no bundle id is available.
        let resolvedBundleIdentifier = executablePath.isEmpty
            ? nil
            : AppBundleIdentifierResolver.bundleIdentifier(forExecutablePath: executablePath)
        let bundleIdentifier = resolvedBundleIdentifier ?? (signingIdentifier.isEmpty ? nil : signingIdentifier)

        return AppLaunchContext(
            bundleIdentifier: bundleIdentifier,
            executablePath: executablePath.isEmpty ? nil : executablePath
        )
    }

    private static func string(from token: es_string_token_t) -> String {
        guard let data = token.data else {
            return ""
        }

        let buffer = UnsafeBufferPointer(start: data, count: Int(token.length))
        return String(decoding: buffer.map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}

private func makePolicyStore() -> AppGuardPolicyStore? {
    guard let appGroupIdentifier = Bundle.main.object(forInfoDictionaryKey: "FermoAppGroupIdentifier") as? String,
          !appGroupIdentifier.isEmpty,
          !appGroupIdentifier.hasPrefix("$("),
          let snapshotURL = AppGuardPolicyStore.defaultSnapshotURL(appGroupIdentifier: appGroupIdentifier)
    else {
        logger.error("FermoAppGuardExtension could not resolve the shared app group policy snapshot")
        return nil
    }

    return AppGuardPolicyStore(snapshotURL: snapshotURL)
}

guard let policyStore = makePolicyStore() else {
    RunLoop.main.run()
    fatalError("RunLoop exited unexpectedly")
}

private let service = FermoAppGuardEndpointSecurityService(policyStore: policyStore)
let startResult = service.start()

switch startResult {
case ES_NEW_CLIENT_RESULT_SUCCESS:
    logger.info("FermoAppGuardExtension subscribed to Endpoint Security auth exec events")
case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
    logger.error("FermoAppGuardExtension is missing com.apple.developer.endpoint-security.client")
case ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED:
    logger.error("FermoAppGuardExtension is not running with required privileges")
case ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED:
    logger.error("FermoAppGuardExtension needs user approval before Endpoint Security can start")
case ES_NEW_CLIENT_RESULT_ERR_INTERNAL:
    logger.error("Endpoint Security client failed with an internal error")
case ES_NEW_CLIENT_RESULT_ERR_INVALID_ARGUMENT:
    logger.error("Endpoint Security client failed because of an invalid argument")
case ES_NEW_CLIENT_RESULT_ERR_TOO_MANY_CLIENTS:
    logger.error("Endpoint Security refused Fermo because too many clients are active")
default:
    logger.error("Endpoint Security client failed with an unknown result")
}

RunLoop.main.run()
fatalError("RunLoop exited unexpectedly")
