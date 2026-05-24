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

logger.info("FermoHelper started with app group \(appGroupIdentifier, privacy: .public)")

Task { @MainActor in
    var didSeeActiveSession = false
    var didRunEmptyCleanup = false
    var lastActiveSessionIDs = Set<UUID>()

    while !Task.isCancelled {
        do {
            let snapshot = try store.load()
            let policy = snapshot.policy
            let now = Date()
            let activeSessions = policy.activeSessions(at: now)
            let activeSessionIDs = Set(activeSessions.map(\.id))

            if activeSessions.isEmpty {
                if didSeeActiveSession || !didRunEmptyCleanup {
                    logger.info("No active persisted session remains; clearing helper rule snapshot")
                    try ruleSnapshotStore.write(.inactive(at: now))
                    didSeeActiveSession = false
                    didRunEmptyCleanup = true
                    lastActiveSessionIDs = []
                }
            } else {
                didSeeActiveSession = true
                didRunEmptyCleanup = false
                if activeSessionIDs != lastActiveSessionIDs {
                    try ruleSnapshotStore.write(ContentFilterRuleSnapshot(policy: policy, at: now))
                    lastActiveSessionIDs = activeSessionIDs
                }

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
