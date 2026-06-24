import FermoCore
import FermoSystem
import AppKit
import OSLog
import SwiftUI

@MainActor
final class FermoViewModel: ObservableObject {
    @Published var policy: FermoPolicy
    @Published var websiteBlockingStatus: WebsiteBlockingStatus = .needsPermission
    @Published var appGuardApprovalStatus: SystemExtensionApprovalStatus = .notRequested
    @Published var helperStatus: HelperRegistrationStatus = .notRegistered
    @Published var isUpdatingWebsiteFilter = false
    @Published var isRequestingAppGuardApproval = false
    @Published var isAppInterruptionMonitorActive = false
    @Published var latestAppInterruptionReport: AppInterruptionReport?
    @Published var systemMessage: String?
    @Published var presets: [FocusPreset] = []
    @Published var customPresets: [FocusPreset] = []
    @Published var savedDraft: SavedContractDraft?
    @Published var schedules: [WeeklySchedule] = []
    @Published var preferences: FermoPreferences = FermoPreferences()

    private let websiteBlockingController: any WebsiteBlockingControlling
    private let protectionRuntimeController: ProtectionRuntimeController
    private let helperRegistrar: HelperRegistrar
    private let sharedStore: JSONFileFermoStore?
    private let contentFilterSnapshotURL: URL?
    private let appGuardSnapshotURL: URL?
    private let appInterruptionController = AppInterruptionController()
    private let filterExtensionActivationController = SystemExtensionActivationController(
        extensionBundleIdentifier: "com.toolary.fermo.filter"
    )
    private let appGuardExtensionActivationController = SystemExtensionActivationController(
        extensionBundleIdentifier: "com.toolary.fermo.appguard"
    )
    private let logger = Logger(subsystem: "com.toolary.fermo", category: "app")
    private var appInterruptionTask: Task<Void, Never>?

    init(websiteBlockingController: (any WebsiteBlockingControlling)? = nil) {
        let appGroupIdentifier = Self.appGroupIdentifierFromBundle()
        let sharedStoreURL = appGroupIdentifier
            .flatMap { JSONFileFermoStore.defaultURL(appGroupIdentifier: $0) }
        let sharedStore = sharedStoreURL.map { JSONFileFermoStore(url: $0) }
        let resolvedWebsiteBlockingController: any WebsiteBlockingControlling = websiteBlockingController ?? NetworkExtensionWebsiteBlockingController(
            configuration: NetworkExtensionFilterConfiguration(appGroupIdentifier: appGroupIdentifier)
        )
        self.helperRegistrar = HelperRegistrar()
        self.sharedStore = sharedStore
        self.contentFilterSnapshotURL = appGroupIdentifier
            .flatMap { ContentFilterRuleSnapshotStore.defaultURL(appGroupIdentifier: $0) }
        self.appGuardSnapshotURL = sharedStoreURL
        self.websiteBlockingController = resolvedWebsiteBlockingController
        self.protectionRuntimeController = ProtectionRuntimeController(
            store: sharedStore,
            websiteBlockingController: resolvedWebsiteBlockingController
        )
        let initialSnapshot = Self.initialSnapshot(sharedStore: sharedStore)
        self.policy = initialSnapshot.policy
        self.schedules = initialSnapshot.schedules
        self.preferences = initialSnapshot.preferences
        self.customPresets = initialSnapshot.customPresets
        self.savedDraft = initialSnapshot.savedDraft
        let builtInPresets = (try? FocusPresetLibrary.defaults()) ?? []
        self.presets = builtInPresets + initialSnapshot.customPresets
        self.helperStatus = helperRegistrar.status()

        if !self.policy.activeSessions(at: Date()).isEmpty {
            logger.info("Active protection found on launch; reconciling runtime adapters")
            Task { await restoreActiveProtectionAfterLaunch() }
        }

        if ProcessInfo.processInfo.environment["FERMO_AUTOSTART_WEBSITE_SPIKE"] == "1" {
            logger.info("Autostart requested for website diagnostic")
            Task { await startWebsiteSpike() }
        }

        if ProcessInfo.processInfo.environment["FERMO_AUTOSTART_APP_SPIKE"] == "1" {
            logger.info("Autostart requested for app diagnostic")
            Task { await startAppSpike() }
        }

        if ProcessInfo.processInfo.environment["FERMO_AUTOSTART_HELPER_SPIKE"] == "1" {
            logger.info("Autostart requested for helper diagnostic")
            Task { await startHelperSpike() }
        }

        if ProcessInfo.processInfo.environment["FERMO_AUTOSTOP_HELPER_SPIKE"] == "1" {
            logger.info("Autostop requested for helper diagnostic")
            Task {
                await stopHelperSpike()
                NSApplication.shared.terminate(nil)
            }
        }
    }

    deinit {
        appInterruptionTask?.cancel()
    }

    var activeSession: FocusSession? {
        policy.activeSessions(at: Date()).first
    }

    var currentContractSession: FocusSession? {
        activeSession ?? proofDueSession
    }

    var proofDueSession: FocusSession? {
        let now = Date()
        return policy.sessions
            .filter { $0.state == .active && now >= $0.endsAt }
            .sorted { $0.endsAt > $1.endsAt }
            .first
    }

    enum MenuBarState: Equatable {
        case idle
        case protected
        case needsApproval
        case degraded
    }

    /// Drives the four state-specific menu-bar popover layouts.
    var menuBarState: MenuBarState {
        if currentContractSession != nil {
            let websiteHealthy = websiteBlockingStatus == .active || websiteBlockingStatus == .ready
            let interruptionStrained = latestAppInterruptionReport?.requiresStrongerHandling == true
            return (!websiteHealthy || interruptionStrained) ? .degraded : .protected
        }
        return onboardingChecklist.overallState == .actionNeeded ? .needsApproval : .idle
    }

    /// Most recent recorded session result, for the menu-bar "last session" summary.
    var lastEvidenceEntry: EvidenceLogEntry? {
        policy.evidenceLog.last
    }

    var isRuleWeakeningLocked: Bool {
        do {
            try LockedModeGuard().validate(.editSessionBlocklists, for: policy, at: Date())
            return false
        } catch {
            return true
        }
    }

    var protectedDomains: [String] {
        policy.activeBlocklists(at: Date()).flatMap { blocklist in
            blocklist.domainRules.map(\.normalizedPattern)
        }
    }

    var protectedApps: [String] {
        Array(policy.blockedAppBundleIdentifiers(at: Date())).sorted()
    }

    var latestEvidenceMarkdown: String? {
        policy.evidenceLog.last.map { EvidenceMarkdownRenderer().render($0) }
    }

    var evidenceExportDirectoryDescription: String {
        evidenceExportDirectoryURL.path
    }

    var evidenceExportDestinationDiagnostic: EvidenceExportDestinationDiagnostic {
        EvidenceExportDestinationDiagnostic.inspect(evidenceExportDirectoryURL)
    }

    var appGuardRuntimeDiagnostic: AppGuardRuntimeDiagnostic? {
        appGuardSnapshotURL.map { AppGuardRuntimeDiagnostic.inspect($0) }
    }

    var contentFilterRuntimeDiagnostic: ContentFilterRuntimeDiagnostic? {
        contentFilterSnapshotURL.map { ContentFilterRuntimeDiagnostic.inspect($0) }
    }

    var diagnosticsReport: String {
        let now = Date()
        let activeSessions = policy.activeSessions(at: now)
        let scheduledSessions = policy.sessions
            .filter { $0.state == .scheduled }
            .sorted { $0.startsAt < $1.startsAt }
        let evidenceDestination = evidenceExportDestinationDiagnostic
        let contentFilterDiagnostic = contentFilterSnapshotURL.map {
            ContentFilterRuntimeDiagnostic.inspect($0, at: now)
        }
        let appGuardDiagnostic = appGuardSnapshotURL.map {
            AppGuardRuntimeDiagnostic.inspect($0, at: now)
        }

        var lines = [
            "# Fermo Diagnostics",
            "",
            "- capturedAt: \(now.formatted(date: .abbreviated, time: .standard))",
            "- websiteFilter: \(websiteBlockingStatus.displayName)",
            "- contentFilterSnapshotState: \(contentFilterDiagnostic?.state.rawValue ?? "unavailable")",
            "- contentFilterSnapshotPath: \(contentFilterDiagnostic?.snapshotPath ?? "missing app group container")",
            "- contentFilterSnapshotMode: \(contentFilterDiagnostic?.mode.rawValue ?? "blocklist")",
            "- contentFilterSnapshotActiveSessions: \(contentFilterDiagnostic?.activeSessionsCount ?? 0)",
            "- contentFilterSnapshotBlockedDomains: \(contentFilterDiagnostic?.blockedDomains.joined(separator: ", ") ?? "")",
            "- contentFilterSnapshotAllowedDomains: \(contentFilterDiagnostic?.allowedDomains.joined(separator: ", ") ?? "")",
            "- contentFilterSnapshotExpiresAt: \(contentFilterDiagnostic?.expiresAt?.formatted(date: .abbreviated, time: .standard) ?? "none")",
            "- contentFilterSnapshotSummary: \(contentFilterDiagnostic?.summary ?? "Content filter snapshot path is unavailable because the app group container was not resolved.")",
            "- appGuardApproval: \(appGuardApprovalStatus.displayName)",
            "- appGuardApprovalDetail: \(appGuardApprovalStatus.detail)",
            "- appGuardSnapshotState: \(appGuardDiagnostic?.state.rawValue ?? "unavailable")",
            "- appGuardSnapshotPath: \(appGuardDiagnostic?.snapshotPath ?? "missing app group container")",
            "- appGuardSnapshotActiveSessions: \(appGuardDiagnostic?.activeSessionsCount ?? 0)",
            "- appGuardSnapshotProtectedApps: \(appGuardDiagnostic?.protectedAppBundleIdentifiers.joined(separator: ", ") ?? "")",
            "- appGuardSnapshotSummary: \(appGuardDiagnostic?.summary ?? "App Guard snapshot path is unavailable because the app group container was not resolved.")",
            "- helper: \(helperStatus.displayName)",
            "- appInterruption: \(appInterruptionStatusText)",
            "- activeSessions: \(activeSessions.count)",
            "- scheduledSessions: \(scheduledSessions.count)",
            "- savedSchedules: \(schedules.count)",
            "- rooms: \(policy.blocklists.count)",
            "- evidenceEntries: \(policy.evidenceLog.count)",
            "- evidenceExportDirectory: \(evidenceExportDirectoryDescription)",
            "- evidenceExportDestination: \(evidenceDestination.state.rawValue)",
            "- evidenceExportDestinationMessage: \(evidenceDestination.message)"
        ]

        if !activeSessions.isEmpty {
            lines.append("")
            lines.append("## Active Sessions")
            lines.append(contentsOf: activeSessions.map { session in
                "- \(session.title) · \(session.rigor.displayName) · ends \(session.endsAt.formatted(date: .omitted, time: .shortened))"
            })
        }

        if !scheduledSessions.isEmpty {
            lines.append("")
            lines.append("## Scheduled Sessions")
            lines.append(contentsOf: scheduledSessions.map { session in
                "- \(session.title) · \(session.rigor.displayName) · starts \(session.startsAt.formatted(date: .abbreviated, time: .shortened))"
            })
        }

        return lines.joined(separator: "\n")
    }

    func blockedDomains(for session: FocusSession) -> [String] {
        policy.blocklists
            .filter { session.blocklistIDs.contains($0.id) }
            .flatMap { $0.domainRules.map(\.normalizedPattern) }
            .sorted()
    }

    func blockedApps(for session: FocusSession) -> [String] {
        policy.blocklists
            .filter { session.blocklistIDs.contains($0.id) }
            .flatMap { $0.appRules.map { "\($0.displayName) · \($0.bundleIdentifier)" } }
            .sorted()
    }

    func allowedDomains(for session: FocusSession) -> [String] {
        (session.contract?.allowedDomains.map(\.normalizedPattern) ?? []).sorted()
    }

    func allowedApps(for session: FocusSession) -> [String] {
        (session.contract?.allowedApps.map { "\($0.displayName) · \($0.bundleIdentifier)" } ?? []).sorted()
    }

    var appInterruptionStatusText: String {
        guard isAppInterruptionMonitorActive else {
            return "idle"
        }

        guard let latestAppInterruptionReport else {
            return "monitoring"
        }

        if latestAppInterruptionReport.interruptedApps.isEmpty {
            return "monitoring, no matching app running"
        }

        if latestAppInterruptionReport.requiresStrongerHandling {
            return "monitoring, stronger handling may be needed"
        }

        if latestAppInterruptionReport.neededSignalTermination {
            return "monitoring, signal terminate requested"
        }

        if latestAppInterruptionReport.neededForceTermination {
            return "monitoring, force terminate requested"
        }

        return "monitoring, terminate requested"
    }

    var onboardingChecklist: ProtectionOnboardingChecklist {
        ProtectionOnboardingChecklist(
            websiteBlockingStatus: websiteBlockingStatus,
            appGuardApprovalStatus: appGuardApprovalStatus,
            helperStatus: helperStatus
        )
    }

    func refreshWebsiteBlockingStatus() async {
        websiteBlockingStatus = await websiteBlockingController.status()
    }

    func refreshHelperStatus() {
        helperStatus = helperRegistrar.status()
    }

    func requestAppGuardApproval() async {
        isRequestingAppGuardApproval = true
        appGuardApprovalStatus = .requested
        defer { isRequestingAppGuardApproval = false }

        do {
            try await appGuardExtensionActivationController.activate()
            appGuardApprovalStatus = .ready
            systemMessage = "App Guard approval request completed. If no macOS prompt appeared, the Endpoint Security extension may already be approved."
        } catch SystemExtensionActivationError.needsUserApproval {
            appGuardApprovalStatus = .needsUserApproval
            systemMessage = "Approve Fermo App Guard in System Settings to enable beta-grade app launch blocking."
        } catch SystemExtensionActivationError.requiresReboot {
            appGuardApprovalStatus = .requiresReboot
            systemMessage = "macOS will finish Fermo App Guard approval after reboot."
        } catch {
            appGuardApprovalStatus = .failed(Self.describe(error))
            systemMessage = "App Guard approval could not be requested: \(Self.describe(error))"
        }
    }

    func startWebsiteSpike() async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            logger.info("Starting website diagnostic")
            let spikePolicy = try FermoSampleData.websiteSpikePolicy()
            policy = spikePolicy
            try protectionRuntimeController.persistPolicy(spikePolicy)
            try await filterExtensionActivationController.activate()
            logger.info("System extension activation request completed")
            try await websiteBlockingController.activate(policy: spikePolicy)
            logger.info("Network Extension filter manager enabled")
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Website diagnostic started. If no macOS prompt appeared, the content filter was already approved. Test reddit.com and youtube.com now."
        } catch {
            logger.error("Website diagnostic could not start: \(Self.describe(error), privacy: .public)")
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Website diagnostic could not start: \(Self.describe(error))"
        }
    }

    func startContract(_ draft: FocusContractDraft) async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            logger.info("Starting focus contract")
            let newPolicy = try draft.activePolicy()
            try await filterExtensionActivationController.activate()
            await requestAppGuardApproval()
            try await websiteBlockingController.activate(policy: newPolicy)
            policy = newPolicy
            try protectionRuntimeController.persistPolicy(newPolicy)
            startAppInterruptionMonitor()
            let report = interruptProtectedAppsOnce()
            let helperMessage = registerHelperForActiveContractIfPossible()
            websiteBlockingStatus = await websiteBlockingController.status()
            let task = newPolicy.sessions.first?.contract?.taskTitle ?? "Focus contract"
            let interruption = report.interruptedApps.isEmpty ? "No matching distracting app was running." : Self.describe(report)
            let appGuardMessage = appGuardApprovalStatus.startSummary
            systemMessage = "\(task) started. If no macOS prompt appeared, protection was already approved on this Mac. \(appGuardMessage) \(interruption) \(helperMessage)"
        } catch {
            logger.error("Focus contract could not start: \(Self.describe(error), privacy: .public)")
            websiteBlockingStatus = await websiteBlockingController.status()
            helperStatus = helperRegistrar.status()
            systemMessage = "Focus contract could not start: \(Self.describe(error))"
        }
    }

    private func restoreActiveProtectionAfterLaunch() async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            try await filterExtensionActivationController.activate()
            await requestAppGuardApproval()
            try await websiteBlockingController.activate(policy: policy)
            startAppInterruptionMonitor()
            let report = interruptProtectedAppsOnce()
            let helperMessage = registerHelperForActiveContractIfPossible()
            websiteBlockingStatus = await websiteBlockingController.status()
            let interruption = report.interruptedApps.isEmpty ? "No matching distracting app was running." : Self.describe(report)
            systemMessage = "Active protection restored after launch. \(appGuardApprovalStatus.startSummary) \(interruption) \(helperMessage)"
        } catch {
            logger.error("Active protection could not be restored after launch: \(Self.describe(error), privacy: .public)")
            websiteBlockingStatus = await websiteBlockingController.status()
            helperStatus = helperRegistrar.status()
            systemMessage = "Active protection was loaded, but runtime restore needs attention: \(Self.describe(error))"
        }
    }

    func startContract(
        taskTitle: String,
        intendedOutcome: String,
        mode: FocusMode,
        rigor: ContractRigor,
        duration: TimeInterval,
        ruleDraft: FocusContractRuleDraft,
        requiredProof: RequiredProof = .markdown
    ) async {
        do {
            let rules = try ruleDraft.resolved()
            await startContract(
                FocusContractDraft(
                    taskTitle: taskTitle,
                    intendedOutcome: intendedOutcome,
                    mode: mode,
                    rigor: rigor,
                    duration: duration,
                    rules: rules,
                    requiredProof: requiredProof
                )
            )
        } catch {
            logger.error("Focus contract rules could not be prepared: \(Self.describe(error), privacy: .public)")
            systemMessage = "Focus contract rules could not be prepared: \(Self.describe(error))"
        }
    }

    func scheduleContract(
        taskTitle: String,
        intendedOutcome: String,
        mode: FocusMode,
        rigor: ContractRigor,
        duration: TimeInterval,
        startsAt: Date,
        ruleDraft: FocusContractRuleDraft,
        requiredProof: RequiredProof = .markdown
    ) async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            let rules = try ruleDraft.resolved()
            let scheduledPolicy = try FocusContractDraft(
                taskTitle: taskTitle,
                intendedOutcome: intendedOutcome,
                mode: mode,
                rigor: rigor,
                duration: duration,
                rules: rules,
                requiredProof: requiredProof
            )
            .scheduledPolicy(startingAt: startsAt)

            var nextPolicy = policy
            nextPolicy.blocklists.append(contentsOf: scheduledPolicy.blocklists)
            nextPolicy.sessions.append(contentsOf: scheduledPolicy.sessions)
            policy = nextPolicy
            try persistSnapshot(policy: nextPolicy)

            try await filterExtensionActivationController.activate()
            try await websiteBlockingController.activate(policy: nextPolicy)
            let helperMessage = registerHelperForActiveContractIfPossible()
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "\(taskTitle) scheduled for \(startsAt.formatted(date: .abbreviated, time: .shortened)). \(helperMessage)"
        } catch {
            logger.error("Focus contract could not be scheduled: \(Self.describe(error), privacy: .public)")
            websiteBlockingStatus = await websiteBlockingController.status()
            helperStatus = helperRegistrar.status()
            systemMessage = "Focus contract could not be scheduled: \(Self.describe(error))"
        }
    }

    func recordEvidence(_ draft: EvidenceDraft) async {
        guard let session = currentContractSession else {
            systemMessage = "No contract to record evidence for."
            return
        }

        do {
            let endedAt = Date()
            let newPolicy = try EvidenceRecorder().record(draft, for: session.id, in: policy, at: endedAt)
            policy = newPolicy
            try protectionRuntimeController.persistPolicy(newPolicy)

            if newPolicy.activeSessions(at: endedAt).isEmpty {
                stopAppInterruptionMonitor()
                do {
                    try await protectionRuntimeController.deactivateWebsiteBlockingAfterTerminalPolicy(newPolicy, at: endedAt)
                } catch {
                    websiteBlockingStatus = await websiteBlockingController.status()
                    systemMessage = "Evidence recorded, but protection cleanup could not finish: \(Self.describe(error))"
                    return
                }
            }

            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Evidence recorded for \(session.contract?.taskTitle ?? session.title)."
        } catch {
            logger.error("Evidence could not be recorded: \(Self.describe(error), privacy: .public)")
            systemMessage = "Evidence could not be recorded: \(Self.describe(error))"
        }
    }

    func stopSoftContract(reason: String) async {
        guard let session = activeSession else {
            systemMessage = "No active contract to stop."
            return
        }

        do {
            try LockedModeGuard().validate(.endSession, for: session, at: Date())
            await recordEvidence(
                EvidenceDraft(
                    outcome: .notCompleted,
                    note: "Stopped early from the active session screen.",
                    notDoneReason: reason
                )
            )
        } catch {
            systemMessage = "Contract cannot stop normally: \(Self.describe(error))"
        }
    }

    func requestRuleWeakeningEdit() {
        do {
            try LockedModeGuard().validate(.editSessionBlocklists, for: policy, at: Date())
            systemMessage = "Rule editing is available because no active Locked or Emergency contract is running."
        } catch {
            systemMessage = "Rule editing is locked: \(Self.describe(error))"
        }
    }

    func saveBlocklist(id: UUID?, draft: BlocklistEditorDraft) {
        do {
            let editor = PolicyEditor()
            let nextPolicy: FermoPolicy
            if let id {
                nextPolicy = try editor.updateBlocklist(id: id, with: draft, in: policy, at: Date())
            } else {
                nextPolicy = try editor.addBlocklist(draft, to: policy, at: Date())
            }

            policy = nextPolicy
            try persistSnapshot(policy: nextPolicy)
            systemMessage = id == nil ? "Room saved." : "Room updated."
        } catch {
            logger.error("Room rules could not be saved: \(Self.describe(error), privacy: .public)")
            systemMessage = "Room rules could not be saved: \(Self.describe(error))"
        }
    }

    func deleteBlocklist(id: UUID) {
        do {
            let nextPolicy = try PolicyEditor().deleteBlocklist(id: id, from: policy, at: Date())
            policy = nextPolicy
            try persistSnapshot(policy: nextPolicy)
            systemMessage = "Room deleted."
        } catch {
            logger.error("Room could not be deleted: \(Self.describe(error), privacy: .public)")
            systemMessage = "Room could not be deleted: \(Self.describe(error))"
        }
    }

    func stopWebsiteSpike() async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            logger.info("Stopping website diagnostic")
            let result = try await protectionRuntimeController.stopDiagnosticProtection(
                kind: .websiteSpike,
                currentPolicy: policy,
                at: Date()
            )
            policy = result.policy
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Website diagnostic stopped and rules cleared. The macOS system extension may still show activated/enabled because approval remains installed."
        } catch {
            logger.error("Website diagnostic could not stop: \(Self.describe(error), privacy: .public)")
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Website diagnostic could not stop: \(Self.describe(error))"
        }
    }

    func startAppSpike() async {
        do {
            logger.info("Starting app blocking diagnostic")
            policy = try FermoSampleData.appBlockingSpikePolicy()
            try protectionRuntimeController.persistPolicy(policy)
            startAppInterruptionMonitor()
            let report = interruptProtectedAppsOnce()
            let target = protectedApps.joined(separator: ", ")
            if report.interruptedApps.isEmpty {
                systemMessage = "App diagnostic started for \(target). Open Calculator to verify interruption."
            } else {
                systemMessage = "App diagnostic started. \(Self.describe(report))"
            }
        } catch {
            logger.error("App diagnostic could not start: \(Self.describe(error), privacy: .public)")
            systemMessage = "App diagnostic could not start: \(Self.describe(error))"
        }
    }

    func stopAppSpike() async {
        do {
            logger.info("Stopping app blocking diagnostic")
            let result = try await protectionRuntimeController.stopDiagnosticProtection(
                kind: .appSpike,
                currentPolicy: policy,
                at: Date()
            )
            stopAppInterruptionMonitor()
            policy = result.policy
            systemMessage = "App diagnostic stopped and state cleared."
        } catch {
            logger.error("App diagnostic could not clear state: \(Self.describe(error), privacy: .public)")
            systemMessage = "App diagnostic stopped, but state could not be cleared: \(Self.describe(error))"
        }
    }

    func startHelperSpike() async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            logger.info("Starting helper persistence diagnostic")
            let spikePolicy = try FermoSampleData.helperPersistenceSpikePolicy()
            policy = spikePolicy
            try protectionRuntimeController.persistPolicyRequired(spikePolicy)
            try await filterExtensionActivationController.activate()
            try await websiteBlockingController.activate(policy: spikePolicy)
            startAppInterruptionMonitor()
            helperStatus = helperRegistrar.status()
            if helperStatus == .enabled {
                try helperRegistrar.unregister()
                try helperRegistrar.register()
            } else if helperStatus == .notRegistered || helperStatus == .notFound {
                try helperRegistrar.register()
            }
            helperStatus = helperRegistrar.status()
            websiteBlockingStatus = await websiteBlockingController.status()

            switch helperStatus {
            case .enabled:
                systemMessage = "Helper diagnostic started. Quit Fermo and verify FermoHelper keeps the session protected."
            case .requiresApproval:
                systemMessage = "Helper registered but needs approval in Login Items."
            case .notFound:
                systemMessage = "Helper registration did not find the embedded login item."
            case .notRegistered:
                systemMessage = "Helper registration returned not registered."
            case .unavailable:
                systemMessage = "Helper registration is unavailable on this macOS build."
            }
        } catch {
            logger.error("Helper diagnostic could not start: \(Self.describe(error), privacy: .public)")
            helperStatus = helperRegistrar.status()
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Helper diagnostic could not start: \(Self.describe(error))"
        }
    }

    func stopHelperSpike() async {
        do {
            logger.info("Stopping helper persistence diagnostic")
            let result = try await protectionRuntimeController.stopDiagnosticProtection(
                kind: .helperSpike,
                currentPolicy: policy,
                at: Date()
            )
            stopAppInterruptionMonitor()
            policy = result.policy
            try helperRegistrar.unregister()
            helperStatus = helperRegistrar.status()
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Helper diagnostic stopped, rules cleared, and helper unregistered."
        } catch {
            logger.error("Helper diagnostic could not stop: \(Self.describe(error), privacy: .public)")
            helperStatus = helperRegistrar.status()
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Helper diagnostic could not stop: \(Self.describe(error))"
        }
    }

    func clearDiagnostics() async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            logger.info("Clearing diagnostic protection")
            let result = try await protectionRuntimeController.stopDiagnosticProtection(
                kind: .allDiagnostics,
                currentPolicy: policy,
                at: Date()
            )
            stopAppInterruptionMonitor()
            policy = result.policy
            websiteBlockingStatus = await websiteBlockingController.status()
            helperStatus = helperRegistrar.status()

            do {
                if helperStatus == .enabled || helperStatus == .requiresApproval {
                    try helperRegistrar.unregister()
                    helperStatus = helperRegistrar.status()
                }
                systemMessage = "Diagnostics cleared. Website rules, app interruption, and helper diagnostic state were reset."
            } catch {
                helperStatus = helperRegistrar.status()
                logger.error("Diagnostics cleared but helper could not be unregistered: \(Self.describe(error), privacy: .public)")
                systemMessage = "Diagnostics cleared, but helper could not be unregistered: \(Self.describe(error))"
            }
        } catch {
            logger.error("Diagnostics could not be cleared: \(Self.describe(error), privacy: .public)")
            websiteBlockingStatus = await websiteBlockingController.status()
            helperStatus = helperRegistrar.status()
            systemMessage = "Diagnostics could not be cleared: \(Self.describe(error))"
        }
    }

    func openLoginItemsSettings() {
        HelperRegistrar.openSystemSettingsLoginItems()
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func saveSchedule(_ schedule: WeeklySchedule) {
        do {
            if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
                schedules[index] = schedule
            } else {
                schedules.append(schedule)
            }
            try persistSnapshot(policy: policy)
            systemMessage = "Schedule saved."
        } catch {
            logger.error("Schedule could not be saved: \(Self.describe(error), privacy: .public)")
            systemMessage = "Schedule could not be saved: \(Self.describe(error))"
        }
    }

    func deleteSchedule(id: UUID) {
        do {
            schedules.removeAll { $0.id == id }
            policy.sessions.removeAll { $0.scheduleID == id }
            try persistSnapshot(policy: policy)
            systemMessage = "Schedule deleted."
        } catch {
            logger.error("Schedule could not be deleted: \(Self.describe(error), privacy: .public)")
            systemMessage = "Schedule could not be deleted: \(Self.describe(error))"
        }
    }

    func chooseEvidenceExportDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = evidenceExportDirectoryURL
        panel.prompt = "Use Folder"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        preferences.evidenceExportDirectoryPath = url.path
        do {
            try persistSnapshot(policy: policy)
            systemMessage = "Evidence export folder updated."
        } catch {
            logger.error("Evidence export folder could not be saved: \(Self.describe(error), privacy: .public)")
            systemMessage = "Evidence export folder could not be saved: \(Self.describe(error))"
        }
    }

    func exportLatestEvidence() {
        guard let entry = policy.evidenceLog.last else {
            systemMessage = "No evidence entry to export."
            return
        }

        do {
            let url = try EvidenceMarkdownExporter().export(entry, to: evidenceExportDirectoryURL)
            systemMessage = "Evidence exported to \(url.path)."
        } catch {
            logger.error("Evidence could not be exported: \(Self.describe(error), privacy: .public)")
            systemMessage = "Evidence could not be exported: \(Self.describe(error))"
        }
    }

    func exportEvidenceLedger() {
        guard !policy.evidenceLog.isEmpty else {
            systemMessage = "No evidence ledger to export."
            return
        }

        do {
            let url = try EvidenceMarkdownExporter().exportLedger(policy.evidenceLog, to: evidenceExportDirectoryURL)
            systemMessage = "Evidence ledger exported to \(url.path)."
        } catch {
            logger.error("Evidence ledger could not be exported: \(Self.describe(error), privacy: .public)")
            systemMessage = "Evidence ledger could not be exported: \(Self.describe(error))"
        }
    }

    func copyDiagnosticsReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticsReport, forType: .string)
        systemMessage = "Diagnostics copied to clipboard."
    }

    func saveContractDefaults(
        presetID: String?,
        rigor: ContractRigor,
        durationMinutes: Int
    ) {
        preferences.defaultPresetID = presetID
        preferences.defaultRigor = rigor
        preferences.defaultDurationMinutes = durationMinutes

        do {
            try persistSnapshot(policy: policy)
            systemMessage = "Contract defaults saved."
        } catch {
            logger.error("Contract defaults could not be saved: \(Self.describe(error), privacy: .public)")
            systemMessage = "Contract defaults could not be saved: \(Self.describe(error))"
        }
    }

    /// Compact one-line summary of a preset for Quick Start rows: "90 min · Locked · Focus Room".
    func presetSummary(_ preset: FocusPreset) -> String {
        "\(preferences.defaultDurationMinutes) min · \(preset.suggestedRigor.displayName) · \(preset.mode.displayName)"
    }

    /// One-action launch of a saved preset (Quick Start), using the default duration.
    func startPreset(_ preset: FocusPreset) async {
        await startContract(
            taskTitle: preset.name,
            intendedOutcome: "Focus session from the \(preset.name) preset.",
            mode: preset.mode,
            rigor: preset.suggestedRigor,
            duration: TimeInterval(preferences.defaultDurationMinutes * 60),
            ruleDraft: FocusContractRuleDraft(preset: preset)
        )
    }

    /// Persist the current Start Contract rules as a reusable custom preset.
    func savePreset(name: String, mode: FocusMode, rigor: ContractRigor, ruleDraft: FocusContractRuleDraft) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            systemMessage = "Preset name is required."
            return
        }
        do {
            let rules = try ruleDraft.resolved()
            let preset = FocusPreset(
                id: "custom-\(UUID().uuidString)",
                name: trimmedName,
                mode: mode,
                suggestedRigor: rigor,
                blockedDomains: rules.blockedDomains,
                blockedApps: rules.blockedApps,
                allowedDomains: rules.allowedDomains,
                allowedApps: rules.allowedApps
            )
            customPresets.append(preset)
            refreshPresets()
            try persistSnapshot(policy: policy)
            systemMessage = "Preset \(trimmedName) saved."
        } catch {
            logger.error("Preset could not be saved: \(Self.describe(error), privacy: .public)")
            systemMessage = "Preset could not be saved: \(Self.describe(error))"
        }
    }

    func deleteCustomPreset(id: String) {
        customPresets.removeAll { $0.id == id }
        refreshPresets()
        do {
            try persistSnapshot(policy: policy)
            systemMessage = "Preset removed."
        } catch {
            systemMessage = "Preset could not be removed: \(Self.describe(error))"
        }
    }

    private func refreshPresets() {
        presets = ((try? FocusPresetLibrary.defaults()) ?? []) + customPresets
    }

    /// Persist a resumable Start Contract draft for the Today "next contract" card.
    func saveDraft(_ draft: SavedContractDraft) {
        savedDraft = draft
        do {
            try persistSnapshot(policy: policy)
            systemMessage = "Draft saved for later."
        } catch {
            logger.error("Draft could not be saved: \(Self.describe(error), privacy: .public)")
            systemMessage = "Draft could not be saved: \(Self.describe(error))"
        }
    }

    func clearSavedDraft() {
        savedDraft = nil
        try? persistSnapshot(policy: policy)
    }

    /// Live Markdown render of an in-progress proof draft (lenient: no validation), for the
    /// Proof Capture preview pane. Mirrors how `EvidenceRecorder` builds the saved entry.
    func proofPreviewMarkdown(for session: FocusSession, draft: EvidenceDraft) -> String {
        let contract = session.contract
        let entry = EvidenceLogEntry(
            sessionID: session.id,
            createdAt: Date(),
            taskTitle: contract?.taskTitle ?? session.title,
            intendedOutcome: contract?.intendedOutcome ?? "",
            outcome: draft.outcome,
            mode: contract?.mode ?? .blocklist,
            rigor: session.rigor,
            startedAt: session.startsAt,
            endedAt: session.endsAt,
            blockedDomains: blockedDomains(for: session),
            blockedApps: blockedApps(for: session),
            allowedDomains: allowedDomains(for: session),
            allowedApps: allowedApps(for: session),
            artifacts: Self.previewArtifacts(from: draft),
            nextStep: draft.nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.nextStep
        )
        return EvidenceMarkdownRenderer().render(entry)
    }

    private static func previewArtifacts(from draft: EvidenceDraft) -> [EvidenceArtifact] {
        func nonEmpty(_ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        var artifacts: [EvidenceArtifact] = []
        if let value = nonEmpty(draft.note) { artifacts.append(.note(value)) }
        if let value = nonEmpty(draft.filePath) { artifacts.append(.filePath(value)) }
        if let value = nonEmpty(draft.commitHash) { artifacts.append(.commitHash(value)) }
        if let value = nonEmpty(draft.screenshotPath) { artifacts.append(.screenshotPath(value)) }
        if let value = nonEmpty(draft.notDoneReason) { artifacts.append(.notDoneReason(value)) }
        if let value = nonEmpty(draft.breakGlassReason) { artifacts.append(.breakGlassReason(value)) }
        return artifacts
    }

    /// Reveal the evidence export folder in Finder, creating it if needed.
    func revealEvidenceFolder() {
        let url = evidenceExportDirectoryURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func copyLatestEvidenceMarkdown() {
        guard let markdown = latestEvidenceMarkdown else {
            systemMessage = "No evidence entry to copy."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        systemMessage = "Latest evidence copied as Markdown."
    }

    func copyEvidenceLedgerMarkdown() {
        guard !policy.evidenceLog.isEmpty else {
            systemMessage = "No evidence ledger to copy."
            return
        }
        let markdown = policy.evidenceLog
            .map { EvidenceMarkdownRenderer().render($0) }
            .joined(separator: "\n---\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
        systemMessage = "Evidence ledger copied as Markdown."
    }

    @discardableResult
    private func interruptProtectedAppsOnce() -> AppInterruptionReport {
        let report = appInterruptionController.interruptPolicyViolatingAppsReport(
            policy: policy,
            at: Date(),
            signalAfterGracefulFailure: true
        )
        latestAppInterruptionReport = report

        if !report.interruptedApps.isEmpty {
            logger.info("App interruption pass: \(Self.describe(report), privacy: .public)")
        }

        return report
    }

    private func registerHelperForActiveContractIfPossible() -> String {
        helperStatus = helperRegistrar.status()

        do {
            switch helperStatus {
            case .enabled:
                return "Helper is enabled for persistence."
            case .notRegistered, .notFound:
                try helperRegistrar.register()
                helperStatus = helperRegistrar.status()
                return helperStatus == .requiresApproval
                    ? "Approve the helper in Login Items to keep protection after quit/login."
                    : "Helper registration requested."
            case .requiresApproval:
                return "Approve the helper in Login Items to keep protection after quit/login."
            case .unavailable:
                return "Helper registration is unavailable in this build."
            }
        } catch {
            helperStatus = helperRegistrar.status()
            return "Helper registration failed: \(Self.describe(error))."
        }
    }

    private func startAppInterruptionMonitor() {
        appInterruptionTask?.cancel()
        isAppInterruptionMonitorActive = true
        appInterruptionTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.interruptProtectedAppsOnce()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func stopAppInterruptionMonitor() {
        appInterruptionTask?.cancel()
        appInterruptionTask = nil
        isAppInterruptionMonitorActive = false
        latestAppInterruptionReport = nil
    }

    private func persistSnapshot(policy: FermoPolicy) throws {
        guard let sharedStore else {
            return
        }

        try sharedStore.save(
            FermoSnapshot(
                policy: policy,
                schedules: schedules,
                preferences: preferences,
                customPresets: customPresets,
                savedDraft: savedDraft
            )
        )
    }

    private var evidenceExportDirectoryURL: URL {
        if let path = preferences.evidenceExportDirectoryPath {
            return URL(fileURLWithPath: path)
        }

        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fermo Evidence", isDirectory: true)
    }

    private static func describe(_ error: any Error) -> String {
        if let systemError = error as? SystemIntegrationError {
            switch systemError {
            case .requiresSignedAppExtension:
                return "signed Network Extension app target required"
            case .helperRegistrationUnavailable:
                return "helper registration unavailable"
            case .helperRegistrationFailed(let message):
                return "helper registration failed: \(message)"
            case .helperUnregistrationFailed(let message):
                return "helper unregistration failed: \(message)"
            case .missingAppGroupContainer(let identifier):
                return "missing app group container \(identifier)"
            case .diagnosticTeardownRejected(let title):
                return "diagnostics cannot clear protected session '\(title)'"
            }
        }

        if let activationError = error as? SystemExtensionActivationError {
            switch activationError {
            case .unavailable:
                return "System Extensions framework unavailable"
            case .needsUserApproval:
                return "approve the Fermo system extension in macOS Settings, then run the diagnostic again"
            case .requiresReboot:
                return "macOS must restart to finish activating the Fermo system extension"
            }
        }

        if let draftError = error as? FocusContractDraftError {
            switch draftError {
            case .emptyTaskTitle:
                return "task title is required"
            case .emptyIntendedOutcome:
                return "intended outcome is required"
            case .missingBlockRules:
                return "blocklist mode needs at least one blocked domain or app"
            case .missingFocusRoomAllowRules:
                return "Focus Room mode needs at least one allowed domain or app"
            }
        }

        if let ruleDraftError = error as? FocusContractRuleDraftError {
            switch ruleDraftError {
            case .emptyAppBundleIdentifier:
                return "app rules need bundle identifiers"
            }
        }

        if let evidenceError = error as? EvidenceRecordError {
            switch evidenceError {
            case .missingProof:
                return "add at least one note, file, commit, screenshot, or reason"
            case .missingNotDoneReason:
                return "not completed needs a reason"
            case .missingBreakGlassReason:
                return "break glass needs a recorded reason"
            case .breakGlassNotApplicable:
                return "break glass only applies to an active locked or emergency session"
            case .lockedSessionStillActive(let until):
                return "locked session is active until \(until.formatted(date: .omitted, time: .shortened)); use break glass with a reason to end early"
            case .sessionNotFound:
                return "session was not found"
            }
        }

        if let lockedError = error as? LockedModeError {
            switch lockedError {
            case .activeSessionLocked(let until):
                return "normal changes are locked until \(until.formatted(date: .omitted, time: .shortened)); use break glass with a reason for an early exit"
            }
        }

        if let editorError = error as? PolicyEditorError {
            switch editorError {
            case .emptyBlocklistName:
                return "room name is required"
            case .blocklistNotFound:
                return "room was not found"
            case .emptyAppBundleIdentifier:
                return "app rule needs a bundle identifier"
            }
        }

        if let validationError = error as? FermoValidationError {
            switch validationError {
            case .emptyDomainRule:
                return "domain rule is empty"
            case .invalidDomainRule(let value):
                return "domain rule is invalid: \(value)"
            case .invalidDuration:
                return "duration is invalid"
            case .emptySchedule:
                return "schedule is empty"
            }
        }

        return error.localizedDescription
    }

    private static func describe(_ report: AppInterruptionReport) -> String {
        if report.interruptedApps.isEmpty {
            return "No matching app is currently running."
        }

        return report.interruptedApps.map { app in
            let pid = app.processIdentifier.map { " pid \($0)" } ?? ""
            switch app.outcome {
            case .terminateRequested:
                return "Requested termination for \(app.displayName)\(pid)."
            case .terminateFailed:
                return "\(app.displayName)\(pid) resisted graceful termination."
            case .signalTerminateRequested:
                return "Sent SIGTERM to \(app.displayName)\(pid)."
            case .signalTerminateFailed:
                return "\(app.displayName)\(pid) resisted SIGTERM."
            case .forceTerminateRequested:
                return "Requested force termination for \(app.displayName)\(pid)."
            case .forceTerminateFailed:
                return "\(app.displayName)\(pid) resisted force termination."
            case .skippedCurrentApp:
                return "Skipped current app \(app.displayName)\(pid)."
            }
        }
        .joined(separator: " ")
    }

    private static func appGroupIdentifierFromBundle() -> String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "FermoAppGroupIdentifier") as? String
        guard let value, !value.isEmpty, !value.hasPrefix("$(") else {
            return nil
        }
        return value
    }

    private static func initialSnapshot(sharedStore: JSONFileFermoStore?) -> FermoSnapshot {
        guard let sharedStore else {
            return FermoSnapshot()
        }

        do {
            return try LaunchRestorePass(store: sharedStore).run().snapshot
        } catch {
            return (try? sharedStore.load()) ?? FermoSnapshot()
        }
    }
}
