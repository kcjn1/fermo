import FermoCore
import Foundation
import NetworkExtension
import OSLog

@objc(FermoFilterDataProvider)
final class FermoFilterDataProvider: NEFilterDataProvider {
    private let logger = Logger(subsystem: "com.toolary.fermo.filter", category: "data-provider")
    private var snapshot = ContentFilterRuleSnapshot()
    private var loadedSnapshotModificationDate: Date?

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        do {
            snapshot = try loadSnapshot(reloadFromDisk: true)
            let loadedSnapshot = snapshot
            let settings = NEFilterSettings(rules: [], defaultAction: .filterData)
            apply(settings) { [logger, loadedSnapshot] error in
                if let error {
                    logger.error("Could not apply content filter settings: \(error.localizedDescription, privacy: .public)")
                    completionHandler(error)
                    return
                }

                logger.info("Started content filter with \(loadedSnapshot.normalizedBlockedDomains.count) blocked domains")
                completionHandler(nil)
            }
        } catch {
            logger.error("Could not start content filter: \(error.localizedDescription, privacy: .public)")
            completionHandler(error)
        }
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        _ = reason
        snapshot = ContentFilterRuleSnapshot()
        loadedSnapshotModificationDate = nil
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let host = host(from: flow) else {
            return .allow()
        }

        let currentSnapshot: ContentFilterRuleSnapshot
        do {
            currentSnapshot = try loadSnapshot(reloadFromDisk: false)
        } catch {
            logger.error("Could not reload content filter snapshot: \(error.localizedDescription, privacy: .public)")
            currentSnapshot = snapshot
        }

        switch currentSnapshot.decision(for: host) {
        case .allow:
            return .allow()
        case .block:
            logger.info("Dropping flow for \(host, privacy: .public)")
            return .drop()
        }
    }

    private func host(from flow: NEFilterFlow) -> String? {
        if let host = flow.url?.host {
            return host
        }

        guard let socketFlow = flow as? NEFilterSocketFlow else {
            return nil
        }

        if #available(macOS 11.0, *) {
            return socketFlow.remoteHostname
        }

        return nil
    }

    private func loadSnapshot(reloadFromDisk: Bool) throws -> ContentFilterRuleSnapshot {
        guard let snapshotURL else {
            snapshot = try fallbackSnapshot()
            loadedSnapshotModificationDate = nil
            return snapshot
        }

        let modificationDate = try snapshotModificationDate(at: snapshotURL)
        if !reloadFromDisk, modificationDate == loadedSnapshotModificationDate {
            return snapshot
        }

        if let loadedSnapshot = try ContentFilterRuleSnapshotStore(fileURL: snapshotURL).load() {
            snapshot = loadedSnapshot
            loadedSnapshotModificationDate = modificationDate
            logger.info(
                "Loaded content filter snapshot with \(loadedSnapshot.normalizedBlockedDomains.count) blocked domains"
            )
            return loadedSnapshot
        }

        snapshot = try fallbackSnapshot()
        loadedSnapshotModificationDate = modificationDate
        return snapshot
    }

    private func snapshotModificationDate(at url: URL) throws -> Date? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date
    }

    private func fallbackSnapshot() throws -> ContentFilterRuleSnapshot {
        #if DEBUG
        return try ContentFilterRuleSnapshot.redditYouTubeSpike()
        #else
        return ContentFilterRuleSnapshot()
        #endif
    }

    private var snapshotURL: URL? {
        let vendorConfiguration = filterConfiguration.vendorConfiguration
        guard let appGroupIdentifier = vendorConfiguration?["FermoAppGroupIdentifier"] as? String else {
            return nil
        }
        let fileName = vendorConfiguration?["FermoSnapshotFileName"] as? String ?? ContentFilterRuleSnapshot.defaultFileName
        return ContentFilterRuleSnapshotStore.defaultURL(
            appGroupIdentifier: appGroupIdentifier,
            fileName: fileName
        )
    }
}
