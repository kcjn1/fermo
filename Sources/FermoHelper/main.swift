import FermoCore
import FermoSystem
import Foundation
import OSLog

let logger = Logger(subsystem: "com.toolary.fermo", category: "helper")
let appGroupIdentifier = Bundle.main.object(forInfoDictionaryKey: "FermoAppGroupIdentifier") as? String
let appInterruptionController = AppInterruptionController()

guard let appGroupIdentifier,
      !appGroupIdentifier.isEmpty,
      !appGroupIdentifier.hasPrefix("$("),
      let snapshotURL = JSONFileFermoStore.defaultURL(appGroupIdentifier: appGroupIdentifier),
      let ruleSnapshotURL = ContentFilterRuleSnapshotStore.defaultURL(appGroupIdentifier: appGroupIdentifier)
else {
    logger.error("FermoHelper could not find the shared app group container")
    RunLoop.main.run()
    fatalError("RunLoop exited unexpectedly")
}

let store = JSONFileFermoStore(url: snapshotURL)
let ruleSnapshotStore = ContentFilterRuleSnapshotStore(fileURL: ruleSnapshotURL)
let restorePass = HelperRestorePass(store: store, ruleSnapshotStore: ruleSnapshotStore)

logger.info("FermoHelper started with app group \(appGroupIdentifier, privacy: .public)")

Task { @MainActor in
    var restoreState = HelperRestorePassState()

    while !Task.isCancelled {
        do {
            let now = Date()
            let restoreResult = try restorePass.run(at: now, state: &restoreState)
            if restoreResult.didSaveSnapshot {
                logger.info("FermoHelper restored due scheduled protection")
            }
            let policy = restoreResult.snapshot.policy
            let activeSessions = policy.activeSessions(at: now)

            if activeSessions.isEmpty {
                if restoreResult.didClearRuleSnapshot {
                    logger.info("No active persisted session remains; clearing helper rule snapshot")
                }
            } else {
                let report = appInterruptionController.interruptPolicyViolatingAppsReport(
                    policy: policy,
                    at: now,
                    signalAfterGracefulFailure: true
                )
                let missingApps = report.missingBundleIdentifiers.sorted().joined(separator: ", ")

                logger.info(
                    "Restored active session from helper. sessions=\(activeSessions.count, privacy: .public) domains=\(policy.activeBlocklists(at: now).flatMap(\.domainRules).count, privacy: .public) appMatches=\(report.interruptedApps.count, privacy: .public) missingApps=\(missingApps, privacy: .public)"
                )
            }
        } catch {
            logger.error("FermoHelper restore pass failed: \(error.localizedDescription, privacy: .public)")
        }

        try? await Task.sleep(for: .seconds(10))
    }
}

RunLoop.main.run()
fatalError("RunLoop exited unexpectedly")
