import FermoCore
import FermoSystem
import AppKit
import OSLog
import SwiftUI
import UniformTypeIdentifiers

#if canImport(SystemExtensions)
import SystemExtensions
#endif

@main
struct FermoApp: App {
    @NSApplicationDelegateAdaptor(FermoApplicationDelegate.self) private var appDelegate
    @StateObject private var model: FermoViewModel

    init() {
        let model = FermoViewModel()
        _model = StateObject(wrappedValue: model)
        FermoMainWindowPresenter.shared.configure(model: model)
    }

    var body: some Scene {
        MenuBarExtra("Fermo", systemImage: "lock.shield") {
            FermoMenuView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

private final class FermoApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            FermoMainWindowPresenter.shared.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        FermoMainWindowPresenter.shared.show()
        return true
    }
}

@MainActor
private final class FermoMainWindowPresenter {
    static let shared = FermoMainWindowPresenter()

    private var model: FermoViewModel?
    private var window: NSWindow?

    func configure(model: FermoViewModel) {
        self.model = model
    }

    func show() {
        guard let model else {
            return
        }

        let window = window ?? makeWindow(model: model)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func makeWindow(model: FermoViewModel) -> NSWindow {
        let hostingController = NSHostingController(rootView: FermoDashboardView(model: model))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Fermo"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1100, height: 760))
        window.minSize = NSSize(width: 980, height: 680)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

@MainActor
final class FermoViewModel: ObservableObject {
    @Published var policy: FermoPolicy
    @Published var websiteBlockingStatus: WebsiteBlockingStatus = .needsPermission
    @Published var helperStatus: HelperRegistrationStatus = .notRegistered
    @Published var isUpdatingWebsiteFilter = false
    @Published var isAppInterruptionMonitorActive = false
    @Published var latestAppInterruptionReport: AppInterruptionReport?
    @Published var systemMessage: String?
    @Published var presets: [FocusPreset] = []
    @Published var hasCompletedOnboarding: Bool
    @Published var permissionProgress = OnboardingProgress(statuses: [])

    private let permissionsProbe = SystemPermissionsProbe()
    private let policyEditor = PolicyEditor()
    private static let onboardingDefaultsKey = "com.toolary.fermo.hasCompletedOnboarding"

    private let websiteBlockingController: any WebsiteBlockingControlling
    private let protectionRuntimeController: ProtectionRuntimeController
    private let helperRegistrar: HelperRegistrar
    private let sharedStore: JSONFileFermoStore?
    private let appInterruptionController = AppInterruptionController()
    private let systemExtensionActivationController = SystemExtensionActivationController()
    private let logger = Logger(subsystem: "com.toolary.fermo", category: "app")
    private var appInterruptionTask: Task<Void, Never>?

    init(websiteBlockingController: (any WebsiteBlockingControlling)? = nil) {
        let appGroupIdentifier = Self.appGroupIdentifierFromBundle()
        let sharedStore = appGroupIdentifier
            .flatMap { JSONFileFermoStore.defaultURL(appGroupIdentifier: $0) }
            .map { JSONFileFermoStore(url: $0) }
        let resolvedWebsiteBlockingController: any WebsiteBlockingControlling = websiteBlockingController ?? NetworkExtensionWebsiteBlockingController(
            configuration: NetworkExtensionFilterConfiguration(appGroupIdentifier: appGroupIdentifier)
        )
        self.helperRegistrar = HelperRegistrar()
        self.sharedStore = sharedStore
        self.websiteBlockingController = resolvedWebsiteBlockingController
        self.protectionRuntimeController = ProtectionRuntimeController(
            store: sharedStore,
            websiteBlockingController: resolvedWebsiteBlockingController
        )
        self.policy = Self.initialPolicy(sharedStore: sharedStore)
        self.presets = (try? FocusPresetLibrary.defaults()) ?? []
        self.helperStatus = helperRegistrar.status()
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingDefaultsKey)

        if ProcessInfo.processInfo.environment["FERMO_AUTOSTART_WEBSITE_SPIKE"] == "1" {
            logger.info("Autostart requested for website spike")
            Task { await startWebsiteSpike() }
        }

        if ProcessInfo.processInfo.environment["FERMO_AUTOSTART_APP_SPIKE"] == "1" {
            logger.info("Autostart requested for app spike")
            Task { await startAppSpike() }
        }

        if ProcessInfo.processInfo.environment["FERMO_AUTOSTART_HELPER_SPIKE"] == "1" {
            logger.info("Autostart requested for helper spike")
            Task { await startHelperSpike() }
        }

        if ProcessInfo.processInfo.environment["FERMO_AUTOSTOP_HELPER_SPIKE"] == "1" {
            logger.info("Autostop requested for helper spike")
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

    func refreshWebsiteBlockingStatus() async {
        websiteBlockingStatus = await websiteBlockingController.status()
    }

    func refreshHelperStatus() {
        helperStatus = helperRegistrar.status()
    }

    func startWebsiteSpike() async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            logger.info("Starting website spike")
            let spikePolicy = try FermoSampleData.websiteSpikePolicy()
            policy = spikePolicy
            try protectionRuntimeController.persistPolicy(spikePolicy)
            try await systemExtensionActivationController.activate()
            logger.info("System extension activation request completed")
            try await websiteBlockingController.activate(policy: spikePolicy)
            logger.info("Network Extension filter manager enabled")
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Website spike started. If no macOS prompt appeared, the content filter was already approved. Test reddit.com and youtube.com now."
        } catch {
            logger.error("Website spike could not start: \(Self.describe(error), privacy: .public)")
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Website spike could not start: \(Self.describe(error))"
        }
    }

    func startContract(_ draft: FocusContractDraft) async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            logger.info("Starting focus contract")
            let newPolicy = try draft.activePolicy()
            try await systemExtensionActivationController.activate()
            try await websiteBlockingController.activate(policy: newPolicy)
            policy = newPolicy
            try protectionRuntimeController.persistPolicy(newPolicy)
            startAppInterruptionMonitor()
            let report = interruptProtectedAppsOnce()
            let helperMessage = registerHelperForActiveContractIfPossible()
            websiteBlockingStatus = await websiteBlockingController.status()
            let task = newPolicy.sessions.first?.contract?.taskTitle ?? "Focus contract"
            let interruption = report.interruptedApps.isEmpty ? "No matching distracting app was running." : Self.describe(report)
            systemMessage = "\(task) started. If no macOS prompt appeared, protection was already approved on this Mac. \(interruption) \(helperMessage)"
        } catch {
            logger.error("Focus contract could not start: \(Self.describe(error), privacy: .public)")
            websiteBlockingStatus = await websiteBlockingController.status()
            helperStatus = helperRegistrar.status()
            systemMessage = "Focus contract could not start: \(Self.describe(error))"
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

    func stopWebsiteSpike() async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            logger.info("Stopping website spike")
            let result = try await protectionRuntimeController.stopDiagnosticProtection(
                kind: .websiteSpike,
                currentPolicy: policy,
                at: Date()
            )
            policy = result.policy
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Website spike stopped and rules cleared. The macOS system extension may still show activated/enabled because approval remains installed."
        } catch {
            logger.error("Website spike could not stop: \(Self.describe(error), privacy: .public)")
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Website spike could not stop: \(Self.describe(error))"
        }
    }

    func startAppSpike() async {
        do {
            logger.info("Starting app blocking spike")
            policy = try FermoSampleData.appBlockingSpikePolicy()
            try protectionRuntimeController.persistPolicy(policy)
            startAppInterruptionMonitor()
            let report = interruptProtectedAppsOnce()
            let target = protectedApps.joined(separator: ", ")
            if report.interruptedApps.isEmpty {
                systemMessage = "App spike started for \(target). Open Calculator to verify interruption."
            } else {
                systemMessage = "App spike started. \(Self.describe(report))"
            }
        } catch {
            logger.error("App spike could not start: \(Self.describe(error), privacy: .public)")
            systemMessage = "App spike could not start: \(Self.describe(error))"
        }
    }

    func stopAppSpike() async {
        do {
            logger.info("Stopping app blocking spike")
            let result = try await protectionRuntimeController.stopDiagnosticProtection(
                kind: .appSpike,
                currentPolicy: policy,
                at: Date()
            )
            stopAppInterruptionMonitor()
            policy = result.policy
            systemMessage = "App spike stopped and state cleared."
        } catch {
            logger.error("App spike could not clear state: \(Self.describe(error), privacy: .public)")
            systemMessage = "App spike stopped, but state could not be cleared: \(Self.describe(error))"
        }
    }

    func startHelperSpike() async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            logger.info("Starting helper persistence spike")
            let spikePolicy = try FermoSampleData.helperPersistenceSpikePolicy()
            policy = spikePolicy
            try protectionRuntimeController.persistPolicyRequired(spikePolicy)
            try await systemExtensionActivationController.activate()
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
                systemMessage = "Helper spike started. Quit Fermo and verify FermoHelper keeps the session protected."
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
            logger.error("Helper spike could not start: \(Self.describe(error), privacy: .public)")
            helperStatus = helperRegistrar.status()
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Helper spike could not start: \(Self.describe(error))"
        }
    }

    func stopHelperSpike() async {
        do {
            logger.info("Stopping helper persistence spike")
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
            systemMessage = "Helper spike stopped, rules cleared, and helper unregistered."
        } catch {
            logger.error("Helper spike could not stop: \(Self.describe(error), privacy: .public)")
            helperStatus = helperRegistrar.status()
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Helper spike could not stop: \(Self.describe(error))"
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
            }
        }

        if let activationError = error as? SystemExtensionActivationError {
            switch activationError {
            case .unavailable:
                return "System Extensions framework unavailable"
            case .needsUserApproval:
                return "approve the Fermo system extension in macOS Settings, then start the spike again"
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

        if let evidenceError = error as? EvidenceRecordError {
            switch evidenceError {
            case .missingProof:
                return "add at least one note, file, commit, screenshot, or reason"
            case .missingNotDoneReason:
                return "not completed needs a reason"
            case .missingBreakGlassReason:
                return "break glass needs a recorded reason"
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

        if let editError = error as? PolicyEditError {
            switch editError {
            case .blocklistNotFound:
                return "that room no longer exists"
            case .duplicateDomain(let value):
                return "\(value) is already blocked here"
            case .duplicateApp(let value):
                return "\(value) is already blocked here"
            case .emptyName:
                return "a room needs a name"
            }
        }

        if let quickBlockError = error as? QuickBlockError {
            switch quickBlockError {
            case .emptyRoom:
                return "this room has no blocked sites or apps yet"
            }
        }

        if let validationError = error as? FermoValidationError {
            switch validationError {
            case .emptyDomainRule:
                return "enter a website to block"
            case .invalidDomainRule(let value):
                return "\(value) is not a valid domain"
            case .invalidDuration:
                return "duration must be greater than zero"
            case .emptySchedule:
                return "schedule needs at least one day"
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

    private static func initialPolicy(sharedStore: JSONFileFermoStore?) -> FermoPolicy {
        if let persistedPolicy = try? sharedStore?.load().policy,
           !persistedPolicy.blocklists.isEmpty || !persistedPolicy.activeSessions(at: Date()).isEmpty {
            return persistedPolicy
        }

        return defaultSeededPolicy()
    }

    /// A usable starting point on first launch: editable rooms derived from the
    /// built-in presets, so Rooms and Quick Block are not empty out of the box.
    static func defaultSeededPolicy() -> FermoPolicy {
        guard let presets = try? FocusPresetLibrary.defaults() else {
            return FermoPolicy()
        }

        let blocklists = presets.map { preset in
            Blocklist(
                name: preset.name,
                domainRules: preset.blockedDomains,
                appRules: preset.blockedApps,
                isEnabled: true
            )
        }
        return FermoPolicy(blocklists: blocklists)
    }
}

private enum SystemExtensionActivationError: Error, Equatable {
    case unavailable
    case needsUserApproval
    case requiresReboot
}

@MainActor
private final class SystemExtensionActivationController {
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

struct FermoMenuView: View {
    @ObservedObject var model: FermoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                FermoMainWindowPresenter.shared.show()
            } label: {
                Label("Open Fermo", systemImage: "macwindow")
            }

            Divider()

            HStack {
                Image(systemName: "lock.shield")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fermo")
                        .font(.headline)
                    Text(model.activeSession == nil ? "No active session" : "Focus session active")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let session = model.activeSession {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.contract?.taskTitle ?? session.title)
                        .font(.subheadline.weight(.semibold))
                    if let outcome = session.contract?.intendedOutcome {
                        Text(outcome)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text("Ends \(session.endsAt.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                    Label("\(session.rigor.rawValue.capitalized) contract", systemImage: session.rigor == .soft ? "hand.raised" : "lock.fill")
                        .font(.caption)
                        .foregroundStyle(session.rigor == .soft ? Color.secondary : Color.orange)
                    if session.contract?.mode == .focusRoom {
                        Label("Focus Room", systemImage: "door.left.hand.closed")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Divider()

            Label("\(model.protectedDomains.count) domains protected", systemImage: "network.badge.shield.half.filled")
            Label("\(model.protectedApps.count) apps protected", systemImage: "app.badge.checkmark")
            Label("Website filter: \(model.websiteBlockingStatus.rawValue)", systemImage: "globe")
            Label("App interruption: \(model.appInterruptionStatusText)", systemImage: "app.dashed")
            Label("Helper: \(model.helperStatus.rawValue)", systemImage: "gearshape.2")

            Divider()

            Button {
                FermoMainWindowPresenter.shared.show()
            } label: {
                Label(model.activeSession == nil ? "Start a Block" : "Manage Session", systemImage: "bolt.shield")
            }

            if let systemMessage = model.systemMessage {
                Text(systemMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 320)
        .task {
            await model.refreshWebsiteBlockingStatus()
            model.refreshHelperStatus()
        }
    }
}

struct FermoDashboardView: View {
    @ObservedObject var model: FermoViewModel
    @State private var selection: FermoArea? = .today

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Session") {
                    ForEach(FermoArea.session) { area in
                        FermoSidebarLabel(area: area)
                    }
                }

                Section("Library") {
                    ForEach(FermoArea.library) { area in
                        FermoSidebarLabel(area: area)
                    }
                }

                Section("System") {
                    ForEach(FermoArea.system) { area in
                        FermoSidebarLabel(area: area)
                    }
                }
            }
            .navigationTitle("Fermo")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            FermoDetailView(selection: $selection, model: model)
        }
        .tint(FermoTheme.accent)
        .frame(minWidth: 980, minHeight: 680)
        .task {
            await model.refreshPermissions()
        }
        .sheet(isPresented: onboardingBinding) {
            FermoOnboardingView(model: model)
                .frame(width: 560, height: 620)
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !model.hasCompletedOnboarding },
            set: { presented in
                if presented == false {
                    model.completeOnboarding()
                }
            }
        )
    }
}

private enum FermoArea: String, CaseIterable, Identifiable, Hashable {
    case today
    case active
    case quickBlock
    case start
    case rooms
    case evidence
    case health
    case preferences

    var id: Self { self }

    static let session: [Self] = [.today, .active, .quickBlock, .start]
    static let library: [Self] = [.rooms, .evidence]
    static let system: [Self] = [.health, .preferences]

    var title: String {
        switch self {
        case .today: "Today"
        case .active: "Active Session"
        case .quickBlock: "Quick Block"
        case .start: "Start Contract"
        case .rooms: "Rooms"
        case .evidence: "Evidence"
        case .health: "System Health"
        case .preferences: "Preferences"
        }
    }

    var symbol: String {
        switch self {
        case .today: "house"
        case .active: "timer"
        case .quickBlock: "bolt.shield"
        case .start: "play.fill"
        case .rooms: "square.grid.2x2"
        case .evidence: "list.bullet.clipboard"
        case .health: "lock.shield"
        case .preferences: "gearshape"
        }
    }
}

private struct FermoSidebarLabel: View {
    let area: FermoArea

    var body: some View {
        Label(area.title, systemImage: area.symbol)
            .tag(area)
    }
}

private struct FermoDetailView: View {
    @Binding var selection: FermoArea?
    @ObservedObject var model: FermoViewModel

    var body: some View {
        Group {
            switch selection ?? .today {
            case .today:
                FermoTodayView(model: model) {
                    selection = .start
                } onOpenActive: {
                    selection = .active
                }
            case .active:
                FermoActiveSessionView(model: model)
            case .quickBlock:
                FermoQuickBlockView(model: model)
            case .start:
                FermoStartContractView(model: model)
            case .rooms:
                FermoRoomsView(model: model)
            case .evidence:
                FermoEvidenceView(model: model)
            case .health:
                FermoSystemHealthView(model: model)
            case .preferences:
                FermoPreferencesView(model: model)
            }
        }
        .background(FermoTheme.background)
    }
}

private enum FermoTheme {
    static let background = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let panel = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let panelRaised = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let line = Color.white.opacity(0.08)
    static let accent = Color(red: 0.39, green: 0.82, blue: 0.68)
    static let warning = Color(red: 0.92, green: 0.65, blue: 0.28)
    static let danger = Color(red: 0.88, green: 0.34, blue: 0.28)
    static let mutedText = Color.secondary
}

private struct FermoScreen<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                content
            }
            .padding(24)
            .frame(maxWidth: 1040, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

private struct FermoPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String?
    @ViewBuilder var content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        symbol: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(FermoTheme.accent)
                        .frame(width: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            content
        }
        .padding(16)
        .background(FermoTheme.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FermoTheme.line)
        )
    }
}

private struct FermoStatusBadge: View {
    enum Tone {
        case ok
        case info
        case warning
        case danger
        case muted

        var color: Color {
            switch self {
            case .ok: FermoTheme.accent
            case .info: .blue
            case .warning: FermoTheme.warning
            case .danger: FermoTheme.danger
            case .muted: .secondary
            }
        }
    }

    let label: String
    var tone: Tone = .ok

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tone.color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(tone.color)
        .background(tone.color.opacity(0.14))
        .clipShape(Capsule())
    }
}

private struct FermoStatusStrip: View {
    let label: String
    let reason: String
    let tone: FermoStatusBadge.Tone
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: tone == .warning ? "exclamationmark.triangle" : "lock.shield")
                .foregroundStyle(tone.color)
            VStack(alignment: .leading, spacing: 3) {
                FermoStatusBadge(label: label, tone: tone)
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(tone.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.color.opacity(0.28))
        )
    }
}

private struct FermoMetric: View {
    let label: String
    let value: String
    let symbol: String
    var tone: FermoStatusBadge.Tone = .ok

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tone.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(FermoTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FermoTodayView: View {
    @ObservedObject var model: FermoViewModel
    let onStartContract: () -> Void
    let onOpenActive: () -> Void

    var body: some View {
        FermoScreen(
            title: "Today",
            subtitle: "One contract, visible system health, and the next honest action."
        ) {
            FermoStatusStrip(
                label: protectionLabel,
                reason: protectionReason,
                tone: protectionTone,
                actionTitle: statusActionTitle,
                action: statusAction
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                FermoPanel("Current Contract", symbol: "target") {
                    if let session = model.currentContractSession {
                        VStack(alignment: .leading, spacing: 12) {
                            ActiveContractSummary(session: session)
                            Button {
                                onOpenActive()
                            } label: {
                                Label("Open Active Session", systemImage: "timer")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FermoTheme.accent)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ready to protect one task.")
                                .font(.title3.weight(.semibold))
                            Text("Choose a preset, write the intended outcome, and start with honest system status visible.")
                                .foregroundStyle(.secondary)
                            Button {
                                onStartContract()
                            } label: {
                                Label("Start Contract", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FermoTheme.accent)
                            .disabled(model.isUpdatingWebsiteFilter)
                        }
                    }
                }

                FermoPanel("Protection Summary", symbol: "lock.shield") {
                    VStack(spacing: 10) {
                        FermoMetric(label: "domains protected", value: "\(model.protectedDomains.count)", symbol: "globe")
                        FermoMetric(label: "apps protected", value: "\(model.protectedApps.count)", symbol: "app.dashed")
                        FermoMetric(label: "helper", value: model.helperStatus.displayName, symbol: "externaldrive", tone: model.helperStatus.tone)
                    }
                }
            }

            FermoPanel("System Health", subtitle: "Signed proof exists locally; lifecycle checks still block beta.", symbol: "network") {
                VStack(spacing: 0) {
                    FermoHealthRow(title: "Network Extension", detail: "Content filter status: \(model.websiteBlockingStatus.displayName).", symbol: "network", tone: model.websiteBlockingStatus.tone)
                    Divider()
                    FermoHealthRow(title: "App Interruption", detail: model.appInterruptionStatusText, symbol: "app.dashed", tone: model.isAppInterruptionMonitorActive ? .ok : .muted)
                    Divider()
                    FermoHealthRow(title: "Helper / Login Item", detail: "Status: \(model.helperStatus.displayName). Main-app quit proof passed locally.", symbol: "externaldrive", tone: model.helperStatus.tone)
                }
            }

            FermoPanel("Recent Evidence", subtitle: "Local proof ledger, rendered as Markdown.", symbol: "list.bullet.clipboard") {
                let entries = Array(model.policy.evidenceLog.suffix(3).reversed())
                if entries.isEmpty {
                    Text("No proof recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(entries) { entry in
                            EvidenceLogRow(entry: entry)
                        }
                    }
                }
            }

            if let systemMessage = model.systemMessage {
                FermoPanel("Last System Message", symbol: "info.circle") {
                    Text(systemMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var protectionLabel: String {
        if model.activeSession != nil { return "Protected" }
        if model.proofDueSession != nil { return "Proof due" }
        if model.websiteBlockingStatus == .active || model.websiteBlockingStatus == .ready { return "Ready" }
        return "Setup needed"
    }

    private var protectionReason: String {
        if let session = model.activeSession {
            return "\(session.rigor.displayName) session in progress. Stop and break-glass behavior depends on the selected rigor."
        }

        if let session = model.proofDueSession {
            return "\(session.contract?.taskTitle ?? session.title) has reached its timer. Record proof to close the contract."
        }

        if model.websiteBlockingStatus == .active || model.websiteBlockingStatus == .ready {
            return "Local signed spike proof passed for website blocking, app interruption, and helper after main-app quit."
        }

        return "Start a signed spike or contract to configure website blocking. macOS only prompts on first approval or replacement, so no prompt is expected after approval already exists."
    }

    private var protectionTone: FermoStatusBadge.Tone {
        if model.activeSession != nil { return .ok }
        if model.proofDueSession != nil { return .warning }
        return (model.websiteBlockingStatus == .active || model.websiteBlockingStatus == .ready) ? .ok : .warning
    }

    private var statusActionTitle: String? {
        (model.websiteBlockingStatus == .active || model.websiteBlockingStatus == .ready) ? nil : "Open System Settings"
    }

    private var statusAction: (() -> Void)? {
        statusActionTitle == nil ? nil : { model.openSystemSettings() }
    }
}

private struct ActiveContractSummary: View {
    let session: FocusSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.contract?.taskTitle ?? session.title)
                .font(.title3.weight(.semibold))
            if let outcome = session.contract?.intendedOutcome {
                Text(outcome)
                    .foregroundStyle(.secondary)
            }
            HStack {
                FermoStatusBadge(label: session.rigor.displayName, tone: session.rigor == .soft ? .muted : .ok)
                FermoStatusBadge(label: session.contract?.mode.displayName ?? "Blocklist", tone: .info)
                Spacer()
                Text("Ends \(session.endsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FermoActiveSessionView: View {
    @ObservedObject var model: FermoViewModel

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            FermoScreen(
                title: "Active Session",
                subtitle: "Timer, enforcement state, rules, proof, and break-glass in one place."
            ) {
                if let session = model.currentContractSession {
                    activeContent(session: session, now: timeline.date)
                } else {
                    FermoPanel("No Active Contract", symbol: "timer") {
                        Text("Start a contract to see its timer, rule boundary, system health, and proof controls here.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func activeContent(session: FocusSession, now: Date) -> some View {
        FermoStatusStrip(
            label: statusLabel(for: session, now: now),
            reason: statusReason(for: session, now: now),
            tone: statusTone(for: session, now: now)
        )

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            FermoPanel("Contract Timer", symbol: "timer") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(timeDisplay(for: session, now: now))
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    ActiveContractSummary(session: session)
                    ProgressView(value: progress(for: session, now: now))
                        .tint(FermoTheme.accent)
                }
            }

            FermoPanel("Runtime Health", symbol: "lock.shield") {
                VStack(spacing: 0) {
                    FermoHealthRow(title: "Website Filter", detail: model.websiteBlockingStatus.displayName, symbol: "network", tone: model.websiteBlockingStatus.tone)
                    Divider()
                    FermoHealthRow(title: "App Interruption", detail: model.appInterruptionStatusText, symbol: "app.dashed", tone: model.isAppInterruptionMonitorActive ? .ok : .warning)
                    Divider()
                    FermoHealthRow(title: "Helper", detail: model.helperStatus.displayName, symbol: "externaldrive", tone: model.helperStatus.tone)
                }
            }
        }

        FermoPanel("Rule Boundary", subtitle: session.contract?.mode.displayName ?? "Blocklist", symbol: "scope") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RuleList(title: "Blocked websites", symbol: "globe", items: model.blockedDomains(for: session))
                RuleList(title: "Blocked apps", symbol: "app.dashed", items: model.blockedApps(for: session))
                RuleList(title: "Allowed websites", symbol: "checkmark.circle", items: model.allowedDomains(for: session))
                RuleList(title: "Allowed apps", symbol: "checkmark.seal", items: model.allowedApps(for: session))
            }
        }

        if let report = model.latestAppInterruptionReport {
            FermoPanel("Last App Interruption Pass", subtitle: report.observedAt.formatted(date: .omitted, time: .standard), symbol: "app.badge.checkmark") {
                VStack(alignment: .leading, spacing: 8) {
                    FermoMetric(label: "requested app targets", value: "\(report.requestedBundleIdentifiers.count)", symbol: "target")
                    FermoMetric(label: "matched running apps", value: "\(report.interruptedApps.count)", symbol: "bolt")
                    if report.requiresStrongerHandling {
                        Text("One or more apps resisted graceful termination. This remains visible because Fermo should not overclaim enforcement.")
                            .font(.caption)
                            .foregroundStyle(FermoTheme.warning)
                    }
                }
            }
        }

        if session.isActive(at: now) {
            if session.rigor == .soft {
                FermoSoftStopPanel(model: model)
                FermoProofCapturePanel(model: model, session: session)
            } else {
                FermoBreakGlassPanel(model: model, session: session)
            }
        } else {
            FermoProofCapturePanel(model: model, session: session)
        }
    }

    private func statusLabel(for session: FocusSession, now: Date) -> String {
        if session.isActive(at: now) {
            return session.rigor == .soft ? "Soft active" : "Protected"
        }
        return "Proof due"
    }

    private func statusReason(for session: FocusSession, now: Date) -> String {
        if session.isActive(at: now), session.rigor != .soft {
            return "Normal stop and rule weakening are locked until \(session.endsAt.formatted(date: .omitted, time: .shortened)). Break glass records a reason."
        }
        if session.isActive(at: now) {
            return "Soft mode can stop early, but Fermo still asks for a local not-done reason or proof."
        }
        return "The timer has elapsed. Record proof to close the contract and clear active protection."
    }

    private func statusTone(for session: FocusSession, now: Date) -> FermoStatusBadge.Tone {
        if !session.isActive(at: now) { return .warning }
        return session.rigor == .soft ? .info : .ok
    }

    private func timeDisplay(for session: FocusSession, now: Date) -> String {
        if now < session.startsAt {
            return formatDuration(session.startsAt.timeIntervalSince(now))
        }
        if now < session.endsAt {
            return formatDuration(session.endsAt.timeIntervalSince(now))
        }
        return "00:00"
    }

    private func progress(for session: FocusSession, now: Date) -> Double {
        guard session.duration > 0 else { return 0 }
        if now <= session.startsAt { return 0 }
        if now >= session.endsAt { return 1 }
        return now.timeIntervalSince(session.startsAt) / session.duration
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        let total = max(0, Int(value.rounded(.up)))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct FermoSoftStopPanel: View {
    @ObservedObject var model: FermoViewModel
    @State private var reason = ""

    var body: some View {
        FermoPanel("Soft Stop", subtitle: "Soft mode permits normal early exit, with an honest local reason.", symbol: "hand.raised") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Reason for stopping early", text: $reason, axis: .vertical)
                    .lineLimit(2...4)
                Button {
                    Task { await model.stopSoftContract(reason: reason) }
                } label: {
                    Label("Stop Soft Contract", systemImage: "stop.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(FermoTheme.warning)
            }
        }
    }
}

private struct FermoBreakGlassPanel: View {
    @ObservedObject var model: FermoViewModel
    let session: FocusSession
    @State private var reason = ""

    var body: some View {
        FermoPanel("Break Glass", subtitle: "Early exit for Locked/Emergency records a reason in evidence.", symbol: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(session.rigor.displayName) mode has no normal stop path while the timer is active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Break-glass reason", text: $reason, axis: .vertical)
                    .lineLimit(2...4)
                Button {
                    Task {
                        await model.recordEvidence(
                            EvidenceDraft(
                                outcome: .breakGlass,
                                note: "Ended early from the active session screen.",
                                breakGlassReason: reason
                            )
                        )
                    }
                } label: {
                    Label("Break Glass and Record", systemImage: "exclamationmark.triangle")
                }
                .buttonStyle(.borderedProminent)
                .tint(FermoTheme.danger)
            }
        }
    }
}

private struct FermoStartContractView: View {
    @ObservedObject var model: FermoViewModel
    @State private var task = "Draft reliability memo"
    @State private var outcome = "Publish a complete first draft with next steps."
    @State private var selectedPresetID = "writing"
    @State private var mode = FocusMode.focusRoom
    @State private var rigor = ContractRigor.locked
    @State private var duration = 90.0
    @AppStorage("com.toolary.fermo.defaultPreset") private var defaultPresetID = ""
    @AppStorage("com.toolary.fermo.defaultDuration") private var defaultDuration = 60.0

    var body: some View {
        FermoScreen(
            title: "Start Contract",
            subtitle: "A fast native flow for task, intended outcome, room, rigor, and proof."
        ) {
            FermoPanel("Contract", subtitle: "Creates a real active FermoCore policy and asks macOS to enforce it.", symbol: "doc.text") {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Task", text: $task)
                    TextField("Intended outcome", text: $outcome, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Preset", selection: $selectedPresetID) {
                        ForEach(model.presets) { value in
                            Text(value.name).tag(value.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Mode", selection: $mode) {
                        Text("Focus Room").tag(FocusMode.focusRoom)
                        Text("Blocklist").tag(FocusMode.blocklist)
                    }
                    .pickerStyle(.segmented)
                    Picker("Rigor", selection: $rigor) {
                        ForEach(ContractRigor.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading) {
                        Text("Duration: \(Int(duration)) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $duration, in: 25...180, step: 5)
                    }
                    Text("Locked means no normal stop path during the session. Fermo does not pretend to be tamper-proof.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        startContract()
                    } label: {
                        Label("Start Contract", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FermoTheme.accent)
                    .disabled(model.isUpdatingWebsiteFilter)
                }
            }

            if let selectedPreset {
                FermoPanel("Selected Room Rules", subtitle: selectedPreset.mode.displayName, symbol: "square.grid.2x2") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        RuleList(
                            title: "Blocked websites",
                            symbol: "globe",
                            items: selectedPreset.blockedDomains.map(\.normalizedPattern)
                        )
                        RuleList(
                            title: "Allowed websites",
                            symbol: "checkmark.circle",
                            items: selectedPreset.allowedDomains.map(\.normalizedPattern)
                        )
                        RuleList(
                            title: "Blocked apps",
                            symbol: "app.dashed",
                            items: selectedPreset.blockedApps.map { "\($0.displayName) · \($0.bundleIdentifier)" }
                        )
                        RuleList(
                            title: "Allowed apps",
                            symbol: "checkmark.seal",
                            items: selectedPreset.allowedApps.map { "\($0.displayName) · \($0.bundleIdentifier)" }
                        )
                    }
                }
            }
        }
        .onAppear(perform: seedDefaults)
        .onChange(of: selectedPresetID) {
            applySelectedPreset()
        }
    }

    private var selectedPreset: FocusPreset? {
        model.presets.first { $0.id == selectedPresetID } ?? model.presets.first
    }

    private func seedDefaults() {
        if !defaultPresetID.isEmpty, model.presets.contains(where: { $0.id == defaultPresetID }) {
            selectedPresetID = defaultPresetID
        }
        duration = defaultDuration
        applySelectedPreset()
    }

    private func applySelectedPreset() {
        guard let selectedPreset else { return }
        mode = selectedPreset.mode
        rigor = selectedPreset.suggestedRigor
    }

    private func startContract() {
        guard let selectedPreset else {
            return
        }

        let draft = FocusContractDraft(
            preset: selectedPreset,
            taskTitle: task,
            intendedOutcome: outcome,
            duration: duration * 60,
            mode: mode,
            rigor: rigor
        )
        Task { await model.startContract(draft) }
    }
}

private struct PresetPreview: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(FermoTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(FermoTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FermoRoomsView: View {
    @ObservedObject var model: FermoViewModel
    @State private var newRoomName = ""

    var body: some View {
        FermoScreen(
            title: "Rooms",
            subtitle: "Reusable focus environments: add the sites and apps you want blocked."
        ) {
            if model.isRuleWeakeningLocked, let session = model.activeSession {
                FermoStatusStrip(
                    label: "Weakening locked",
                    reason: "\(session.rigor.displayName) session is active. You can still add blocks, but removing them is locked until \(session.endsAt.formatted(date: .omitted, time: .shortened)).",
                    tone: .warning
                )
            }

            FermoPanel("New Room", subtitle: "Group related distractions you want to block together.", symbol: "plus.square.on.square") {
                HStack {
                    TextField("Room name (e.g. Social Media)", text: $newRoomName)
                        .onSubmit(createRoom)
                    Button("Add Room", action: createRoom)
                        .buttonStyle(.borderedProminent)
                        .tint(FermoTheme.accent)
                        .disabled(newRoomName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if model.policy.blocklists.isEmpty {
                FermoPanel("No Rooms Yet", symbol: "square.grid.2x2") {
                    Text("Create a room above, then add the websites and apps you want Fermo to block during a session.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(model.policy.blocklists) { blocklist in
                    RoomEditorCard(model: model, blocklist: blocklist)
                }
            }
        }
    }

    private func createRoom() {
        let name = newRoomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        model.createRoom(named: name)
        newRoomName = ""
    }
}

private struct RoomEditorCard: View {
    @ObservedObject var model: FermoViewModel
    let blocklist: Blocklist
    @State private var newDomain = ""
    @State private var showingAppImporter = false

    var body: some View {
        FermoPanel(
            blocklist.name,
            subtitle: "\(blocklist.domainRules.count) sites · \(blocklist.appRules.count) apps",
            symbol: "door.left.hand.closed"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Toggle("Enabled", isOn: Binding(
                        get: { blocklist.isEnabled },
                        set: { newValue in Task { await model.setRoom(blocklist.id, enabled: newValue) } }
                    ))
                    .toggleStyle(.switch)
                    .tint(FermoTheme.accent)
                    Spacer()
                    Button(role: .destructive) {
                        Task { await model.deleteRoom(blocklist.id) }
                    } label: {
                        Label("Delete Room", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRuleWeakeningLocked)
                }

                // Websites
                VStack(alignment: .leading, spacing: 8) {
                    Label("Blocked websites", systemImage: "globe")
                        .font(.subheadline.weight(.semibold))
                    Text("Blocked in every browser (Safari, Chrome, Arc, Dia, Firefox…) via the network filter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Add website (e.g. reddit.com)", text: $newDomain)
                            .onSubmit(addDomain)
                        Button("Add", action: addDomain)
                            .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ForEach(blocklist.domainRules.map(\.normalizedPattern).sorted(), id: \.self) { pattern in
                        HStack {
                            Text(pattern)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                Task { await model.removeDomain(pattern, from: blocklist.id) }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .disabled(model.isRuleWeakeningLocked)
                        }
                    }
                }

                Divider()

                // Apps
                VStack(alignment: .leading, spacing: 8) {
                    Label("Blocked apps", systemImage: "app.dashed")
                        .font(.subheadline.weight(.semibold))
                    Text("Blocked apps are asked to quit during a session. To block only a website, add the site above instead of the browser.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        showingAppImporter = true
                    } label: {
                        Label("Add App…", systemImage: "plus.app")
                    }
                    ForEach(blocklist.appRules.sorted { $0.displayName < $1.displayName }, id: \.bundleIdentifier) { rule in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(rule.displayName)
                                        .font(.caption.weight(.semibold))
                                    if model.isBrowserBundleIdentifier(rule.bundleIdentifier) {
                                        Text("browser")
                                            .font(.caption2)
                                            .foregroundStyle(FermoTheme.warning)
                                    }
                                }
                                Text(rule.bundleIdentifier)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                Task { await model.removeApp(rule.bundleIdentifier, from: blocklist.id) }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .disabled(model.isRuleWeakeningLocked)
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingAppImporter,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await model.addApp(from: url, to: blocklist.id) }
                }
            case .failure(let error):
                model.systemMessage = "Could not pick app: \(error.localizedDescription)"
            }
        }
    }

    private func addDomain() {
        let value = newDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        Task { await model.addDomain(value, to: blocklist.id) }
        newDomain = ""
    }
}

private struct FermoQuickBlockView: View {
    @ObservedObject var model: FermoViewModel
    @State private var selectedRoomID: UUID?
    @AppStorage("com.toolary.fermo.defaultDuration") private var duration = 60.0
    @AppStorage("com.toolary.fermo.defaultRigor") private var rigorRaw = ContractRigor.soft.rawValue

    private var rigor: ContractRigor { ContractRigor(rawValue: rigorRaw) ?? .soft }

    private var selectedRoom: Blocklist? {
        model.policy.blocklists.first { $0.id == selectedRoomID } ?? model.policy.blocklists.first
    }

    var body: some View {
        FermoScreen(
            title: "Quick Block",
            subtitle: "Block a room right now — no task or outcome required."
        ) {
            if model.activeSession != nil {
                FermoStatusStrip(
                    label: "Session already active",
                    reason: "Finish or break glass on the current session before starting a new block.",
                    tone: .warning
                )
            }

            FermoPanel("Block Now", subtitle: "Pick a room, set how long, and start.", symbol: "bolt.shield") {
                if model.policy.blocklists.isEmpty {
                    Text("Create a room in Rooms first, then come back to Quick Block.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Room", selection: Binding(
                            get: { selectedRoom?.id ?? model.policy.blocklists.first?.id },
                            set: { selectedRoomID = $0 }
                        )) {
                            ForEach(model.policy.blocklists) { room in
                                Text(room.name).tag(Optional(room.id))
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Rigor", selection: Binding(
                            get: { rigor },
                            set: { rigorRaw = $0.rawValue }
                        )) {
                            ForEach(ContractRigor.allCases, id: \.self) { value in
                                Text(value.displayName).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading) {
                            Text("Duration: \(Int(duration)) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $duration, in: 5...240, step: 5)
                        }

                        Text(rigor == .soft
                             ? "Soft blocks let you stop early with an honest reason."
                             : "\(rigor.displayName) blocks have no normal stop path until the timer ends. Fermo is not tamper-proof.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            if let room = selectedRoom {
                                Task { await model.startQuickBlock(room: room, duration: duration * 60, rigor: rigor) }
                            }
                        } label: {
                            Label("Start Quick Block", systemImage: "bolt.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FermoTheme.accent)
                        .disabled(model.isUpdatingWebsiteFilter || model.activeSession != nil || selectedRoom == nil)
                    }
                }
            }

            if let room = selectedRoom {
                FermoPanel("What \(room.name) blocks", symbol: "scope") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        RuleList(title: "Blocked websites", symbol: "globe", items: room.domainRules.map(\.normalizedPattern))
                        RuleList(title: "Blocked apps", symbol: "app.dashed", items: room.appRules.map { "\($0.displayName) · \($0.bundleIdentifier)" })
                    }
                }
            }
        }
    }
}

private struct FermoOnboardingView: View {
    @ObservedObject var model: FermoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Welcome to Fermo", systemImage: "lock.shield")
                    .font(.title2.weight(.semibold))
                Text("Fermo blocks distracting sites and apps during a focus session. Grant these once so protection can actually hold. You stay in control — nothing is enforced until you start a session.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    PermissionRow(
                        kind: .websiteFilter,
                        state: model.permissionProgress.state(for: .websiteFilter),
                        detail: "Required. A macOS network filter blocks sites in every browser (Safari, Chrome, Arc, Dia, Firefox).",
                        actionTitle: "Enable"
                    ) {
                        await model.requestWebsiteFilter()
                    }

                    PermissionRow(
                        kind: .loginItem,
                        state: model.permissionProgress.state(for: .loginItem),
                        detail: "Recommended. Keeps protection running after you quit Fermo and after login.",
                        actionTitle: "Register"
                    ) {
                        await model.requestLoginItem()
                    }

                    PermissionRow(
                        kind: .notifications,
                        state: model.permissionProgress.state(for: .notifications),
                        detail: "Optional. Alerts you when a session starts, ends, or protection degrades.",
                        actionTitle: "Allow"
                    ) {
                        await model.requestNotifications()
                    }

                    PermissionRow(
                        kind: .accessibility,
                        state: model.permissionProgress.state(for: .accessibility),
                        detail: "Optional. Not needed today; reserved for stronger app blocking later. Opens System Settings.",
                        actionTitle: "Open Settings"
                    ) {
                        await model.requestAccessibility()
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Open System Settings") { model.openSystemSettings() }
                    .buttonStyle(.bordered)
                Spacer()
                Text("\(model.permissionProgress.satisfiedCount)/\(model.permissionProgress.totalCount) granted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(model.permissionProgress.isReady ? "Finish" : "Continue Anyway") {
                    model.completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .tint(FermoTheme.accent)
            }
            .padding(20)
        }
        .background(FermoTheme.background)
        .task { await model.refreshPermissions() }
    }
}

private struct PermissionRow: View {
    let kind: PermissionKind
    let state: PermissionState
    let detail: String
    let actionTitle: String
    let action: () async -> Void
    @State private var isWorking = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tone.color)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(kind.title)
                        .font(.subheadline.weight(.semibold))
                    if kind.isRequired {
                        Text("required")
                            .font(.caption2)
                            .foregroundStyle(FermoTheme.warning)
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                FermoStatusBadge(label: stateLabel, tone: tone)
                if state != .satisfied {
                    Button {
                        isWorking = true
                        Task {
                            await action()
                            isWorking = false
                        }
                    } label: {
                        if isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(actionTitle)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking)
                }
            }
        }
        .padding(14)
        .background(FermoTheme.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(FermoTheme.line))
    }

    private var symbol: String {
        switch kind {
        case .websiteFilter: "network"
        case .loginItem: "externaldrive"
        case .notifications: "bell"
        case .accessibility: "accessibility"
        }
    }

    private var stateLabel: String {
        switch state {
        case .satisfied: "Granted"
        case .needsApproval: "Approve in Settings"
        case .notDetermined: "Not set"
        case .unavailable: "Unavailable"
        }
    }

    private var tone: FermoStatusBadge.Tone {
        switch state {
        case .satisfied: .ok
        case .needsApproval: .warning
        case .notDetermined: .muted
        case .unavailable: .danger
        }
    }
}

private struct RuleList: View {
    let title: String
    let symbol: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
            if items.isEmpty {
                Text("None recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FermoTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FermoEvidenceView: View {
    @ObservedObject var model: FermoViewModel
    @AppStorage("com.toolary.fermo.evidenceDirectory") private var evidenceDirectory = ""

    var body: some View {
        FermoScreen(
            title: "Evidence",
            subtitle: "A local Markdown ledger for the contract you actually ran."
        ) {
            if let session = model.currentContractSession {
                if session.isActive(at: Date()), session.rigor != .soft {
                    FermoBreakGlassPanel(model: model, session: session)
                } else {
                    FermoProofCapturePanel(model: model, session: session)
                }
            }

            FermoPanel("Ledger", subtitle: "\(model.policy.evidenceLog.count) local entries", symbol: "list.bullet.clipboard") {
                HStack {
                    Button {
                        export(text: model.ledgerMarkdown(), suggestedName: "fermo-evidence-ledger.md")
                    } label: {
                        Label("Export Ledger…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.policy.evidenceLog.isEmpty)

                    if let latest = model.policy.evidenceLog.last {
                        Button {
                            export(text: model.markdown(for: latest), suggestedName: "fermo-\(latest.sessionID.uuidString.prefix(8)).md")
                        } label: {
                            Label("Export Latest…", systemImage: "doc.badge.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.bottom, 4)

                let entries = Array(model.policy.evidenceLog.reversed())
                if entries.isEmpty {
                    Text("No evidence recorded yet. Complete a contract, attach proof, or use break glass with a reason.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(entries) { entry in
                            EvidenceLogRow(entry: entry)
                            if entry.id != entries.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            if let markdown = model.latestEvidenceMarkdown {
                FermoPanel("Latest Markdown Preview", symbol: "doc.plaintext") {
                    ScrollView(.horizontal) {
                        Text(markdown)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func export(text: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        if !evidenceDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: evidenceDirectory, isDirectory: true)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            evidenceDirectory = url.deletingLastPathComponent().path
            model.systemMessage = "Exported evidence to \(url.lastPathComponent)."
        } catch {
            model.systemMessage = "Could not export evidence: \(error.localizedDescription)"
        }
    }
}

private struct FermoProofCapturePanel: View {
    @ObservedObject var model: FermoViewModel
    let session: FocusSession
    @State private var outcome = EvidenceOutcome.completed
    @State private var note = ""
    @State private var filePath = ""
    @State private var commitHash = ""
    @State private var notDoneReason = ""
    @State private var breakGlassReason = ""
    @State private var nextStep = ""

    var body: some View {
        FermoPanel(
            "Record Proof",
            subtitle: "Locked and Emergency contracts need the timer to finish, unless you record break glass.",
            symbol: "checkmark.seal"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ActiveContractSummary(session: session)

                Picker("Outcome", selection: $outcome) {
                    ForEach(EvidenceOutcome.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Proof note", text: $note, axis: .vertical)
                    .lineLimit(2...5)
                HStack {
                    TextField("File path", text: $filePath)
                    TextField("Commit hash", text: $commitHash)
                }
                if outcome == .notCompleted {
                    TextField("Reason not completed", text: $notDoneReason, axis: .vertical)
                        .lineLimit(2...4)
                }
                if outcome == .breakGlass {
                    TextField("Break-glass reason", text: $breakGlassReason, axis: .vertical)
                        .lineLimit(2...4)
                }
                TextField("Next step", text: $nextStep)

                Button {
                    record()
                } label: {
                    Label(outcome == .breakGlass ? "Break Glass and Record" : "Record Evidence", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(outcome == .breakGlass ? FermoTheme.warning : FermoTheme.accent)
            }
        }
    }

    private func record() {
        Task {
            await model.recordEvidence(
                EvidenceDraft(
                    outcome: outcome,
                    note: note,
                    filePath: filePath,
                    commitHash: commitHash,
                    notDoneReason: notDoneReason,
                    breakGlassReason: breakGlassReason,
                    nextStep: nextStep
                )
            )
            note = ""
            filePath = ""
            commitHash = ""
            notDoneReason = ""
            breakGlassReason = ""
            nextStep = ""
        }
    }
}

private struct EvidenceLogRow: View {
    let entry: EvidenceLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.outcome == .breakGlass ? "exclamationmark.triangle" : "doc.text")
                .foregroundStyle(entry.outcome.tone.color)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.taskTitle)
                    .font(.subheadline.weight(.semibold))
                Text(entry.intendedOutcome)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(entry.startedAt.formatted(date: .omitted, time: .shortened))-\(entry.endedAt.formatted(date: .omitted, time: .shortened)) · \(entry.mode.displayName) · \(entry.rigor.displayName)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            FermoStatusBadge(label: entry.outcome.displayName, tone: entry.outcome.tone)
        }
        .padding(.vertical, 4)
    }
}

private struct EvidencePreviewRow: View {
    let task: String
    let outcome: String
    let proof: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(FermoTheme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(task)
                    .font(.subheadline.weight(.semibold))
                Text(proof)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            FermoStatusBadge(label: outcome, tone: outcome == "completed" ? .ok : .warning)
        }
        .padding(.vertical, 4)
    }
}

private struct FermoSystemHealthView: View {
    @ObservedObject var model: FermoViewModel

    var body: some View {
        FermoScreen(
            title: "System Health",
            subtitle: "What macOS lets Fermo enforce, in plain language."
        ) {
            FermoStatusStrip(
                label: model.permissionProgress.isReady ? "Protection ready" : "Setup needed",
                reason: model.permissionProgress.isReady
                    ? "Required permissions are granted. Website and app blocking can run during a session."
                    : "The website filter still needs approval before blocking can be trusted. Open onboarding or System Settings.",
                tone: model.permissionProgress.isReady ? .ok : .warning,
                actionTitle: model.permissionProgress.isReady ? nil : "Run Setup",
                action: model.permissionProgress.isReady ? nil : { model.reopenOnboarding() }
            )

            FermoPanel("Approvals & Extensions", symbol: "lock.shield") {
                VStack(spacing: 0) {
                    FermoHealthRow(title: "Network Extension Content Filter", detail: "Status: \(model.websiteBlockingStatus.displayName).", symbol: "network", tone: model.websiteBlockingStatus.tone)
                    Divider()
                    FermoHealthRow(title: "Helper / Login Item", detail: "Status: \(model.helperStatus.displayName).", symbol: "externaldrive", tone: model.helperStatus.tone)
                    Divider()
                    FermoHealthRow(title: "Notifications", detail: "Status: \(Self.stateLabel(model.permissionProgress.state(for: .notifications))).", symbol: "bell", tone: Self.tone(for: model.permissionProgress.state(for: .notifications)))
                    Divider()
                    FermoHealthRow(title: "App Control (Accessibility)", detail: "Status: \(Self.stateLabel(model.permissionProgress.state(for: .accessibility))). Optional today.", symbol: "accessibility", tone: Self.tone(for: model.permissionProgress.state(for: .accessibility)))
                }
            }

            FermoPanel("Blocking & Interruption", symbol: "shield") {
                VStack(spacing: 0) {
                    FermoHealthRow(title: "Website Blocking", detail: "\(model.protectedDomains.count) domains blocked in the active session, across every browser.", symbol: "globe", tone: model.websiteBlockingStatus.tone)
                    Divider()
                    FermoHealthRow(title: "App Interruption", detail: model.appInterruptionStatusText, symbol: "app.dashed", tone: model.isAppInterruptionMonitorActive ? .ok : .muted)
                    Divider()
                    FermoHealthRow(title: "Enforcement Honesty", detail: "App blocking asks apps to quit; it is not tamper-proof and does not use Endpoint Security.", symbol: "info.circle", tone: .muted)
                }
            }

            FermoPanel("Verify Before Trusting a Beta", subtitle: "Checks that a signed build must still pass manually.", symbol: "questionmark.circle") {
                VStack(spacing: 0) {
                    ManualCheckRow("Sleep / wake restore")
                    Divider()
                    ManualCheckRow("Reboot / login restore")
                    Divider()
                    ManualCheckRow("Wi-Fi change")
                    Divider()
                    ManualCheckRow("Firefox and private/incognito windows")
                }
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Low-level spikes for debugging the Network Extension, app interruption, and helper. Not part of normal use.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Website Spike") { Task { await model.startWebsiteSpike() } }
                        Button("Stop") { Task { await model.stopWebsiteSpike() } }
                    }
                    HStack {
                        Button("App Spike") { Task { await model.startAppSpike() } }
                        Button("Stop Apps") { Task { await model.stopAppSpike() } }
                            .disabled(!model.isAppInterruptionMonitorActive)
                    }
                    HStack {
                        Button("Helper Spike") { Task { await model.startHelperSpike() } }
                        Button("Unregister Helper") { Task { await model.stopHelperSpike() } }
                    }
                    Button("Open Login Items") { model.openLoginItemsSettings() }
                }
                .padding(.top, 8)
            } label: {
                Label("Diagnostics (advanced)", systemImage: "wrench.and.screwdriver")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .background(FermoTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private static func stateLabel(_ state: PermissionState) -> String {
        switch state {
        case .satisfied: "Granted"
        case .needsApproval: "Needs approval"
        case .notDetermined: "Not set"
        case .unavailable: "Unavailable"
        }
    }

    private static func tone(for state: PermissionState) -> FermoStatusBadge.Tone {
        switch state {
        case .satisfied: .ok
        case .needsApproval: .warning
        case .notDetermined: .muted
        case .unavailable: .danger
        }
    }
}

private struct FermoHealthRow: View {
    let title: String
    let detail: String
    let symbol: String
    let tone: FermoStatusBadge.Tone

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tone.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            FermoStatusBadge(label: tone.label, tone: tone)
        }
        .padding(.vertical, 10)
    }
}

private struct ManualCheckRow: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        FermoHealthRow(
            title: title,
            detail: "Unverified in the current local signed spike. Keep visible before any beta claim.",
            symbol: "questionmark.circle",
            tone: .warning
        )
    }
}

private struct FermoPreferencesView: View {
    @ObservedObject var model: FermoViewModel
    @AppStorage("com.toolary.fermo.defaultPreset") private var defaultPresetID = ""
    @AppStorage("com.toolary.fermo.defaultRigor") private var defaultRigorRaw = ContractRigor.soft.rawValue
    @AppStorage("com.toolary.fermo.defaultDuration") private var defaultDuration = 60.0
    @AppStorage("com.toolary.fermo.evidenceDirectory") private var evidenceDirectory = ""

    var body: some View {
        FermoScreen(
            title: "Preferences",
            subtitle: "Defaults, permissions, evidence storage, and helper."
        ) {
            FermoPanel("Session Defaults", subtitle: "Prefilled when you start a Quick Block or contract.", symbol: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Default preset", selection: $defaultPresetID) {
                        Text("None").tag("")
                        ForEach(model.presets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    Picker("Default rigor", selection: $defaultRigorRaw) {
                        ForEach(ContractRigor.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading) {
                        Text("Default duration: \(Int(defaultDuration)) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $defaultDuration, in: 5...240, step: 5)
                    }
                }
            }

            FermoPanel("Permissions", subtitle: "\(model.permissionProgress.satisfiedCount)/\(model.permissionProgress.totalCount) granted.", symbol: "lock.shield") {
                VStack(alignment: .leading, spacing: 10) {
                    FermoHealthRow(title: "Website filter", detail: model.websiteBlockingStatus.displayName, symbol: "network", tone: model.websiteBlockingStatus.tone)
                    FermoHealthRow(title: "Helper / Login Item", detail: model.helperStatus.displayName, symbol: "externaldrive", tone: model.helperStatus.tone)
                    HStack {
                        Button("Re-run Setup") { model.reopenOnboarding() }
                            .buttonStyle(.borderedProminent)
                            .tint(FermoTheme.accent)
                        Button("Open Login Items") { model.openLoginItemsSettings() }
                            .buttonStyle(.bordered)
                        Button("Open System Settings") { model.openSystemSettings() }
                            .buttonStyle(.bordered)
                    }
                }
            }

            FermoPanel("Evidence Storage", subtitle: "Where exported Markdown is saved by default.", symbol: "folder") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(evidenceDirectory.isEmpty ? "No default folder chosen. You'll pick a location each export." : evidenceDirectory)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Choose Folder…") { chooseEvidenceDirectory() }
                            .buttonStyle(.bordered)
                        if !evidenceDirectory.isEmpty {
                            Button("Clear") { evidenceDirectory = "" }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            FermoPanel("Privacy", symbol: "hand.raised") {
                Text("Fermo stores rooms, sessions, and evidence locally. No cloud sync and no AI calls in v1.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func chooseEvidenceDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            evidenceDirectory = url.path
        }
    }
}

private extension FermoStatusBadge.Tone {
    var label: String {
        switch self {
        case .ok: "Ready"
        case .info: "Needs approval"
        case .warning: "Unverified"
        case .danger: "Error"
        case .muted: "Not installed"
        }
    }
}

private extension WebsiteBlockingStatus {
    var displayName: String {
        switch self {
        case .unavailable: "Unavailable"
        case .needsPermission: "Setup needed"
        case .ready: "Ready"
        case .active: "Active"
        }
    }

    var tone: FermoStatusBadge.Tone {
        switch self {
        case .active, .ready: .ok
        case .needsPermission: .warning
        case .unavailable: .muted
        }
    }
}

private extension HelperRegistrationStatus {
    var displayName: String {
        switch self {
        case .unavailable: "Unavailable"
        case .notRegistered: "Not registered"
        case .requiresApproval: "Needs approval"
        case .enabled: "Enabled"
        case .notFound: "Not found"
        }
    }

    var tone: FermoStatusBadge.Tone {
        switch self {
        case .enabled: .ok
        case .requiresApproval: .warning
        case .notRegistered, .notFound, .unavailable: .muted
        }
    }
}

private extension FocusMode {
    var displayName: String {
        switch self {
        case .blocklist: "Blocklist"
        case .focusRoom: "Focus Room"
        }
    }
}

private extension ContractRigor {
    var displayName: String {
        switch self {
        case .soft: "Soft"
        case .locked: "Locked"
        case .emergency: "Emergency"
        }
    }
}

private extension EvidenceOutcome {
    var displayName: String {
        switch self {
        case .completed: "Completed"
        case .partiallyCompleted: "Partial"
        case .notCompleted: "Not done"
        case .breakGlass: "Break glass"
        }
    }

    var tone: FermoStatusBadge.Tone {
        switch self {
        case .completed: .ok
        case .partiallyCompleted: .warning
        case .notCompleted: .muted
        case .breakGlass: .danger
        }
    }
}

// MARK: - Onboarding, permissions, editing, Quick Block, export

extension FermoViewModel {
    // MARK: Permissions

    func refreshPermissions() async {
        websiteBlockingStatus = await websiteBlockingController.status()
        helperStatus = helperRegistrar.status()
        let notifications = await permissionsProbe.notificationState()
        let accessibility = permissionsProbe.accessibilityState()
        permissionProgress = OnboardingProgress(statuses: [
            PermissionStatus(kind: .websiteFilter, state: Self.filterPermissionState(websiteBlockingStatus)),
            PermissionStatus(kind: .loginItem, state: Self.loginPermissionState(helperStatus)),
            PermissionStatus(kind: .notifications, state: notifications),
            PermissionStatus(kind: .accessibility, state: accessibility)
        ])
    }

    func requestWebsiteFilter() async {
        do {
            try await systemExtensionActivationController.activate()
            try await websiteBlockingController.prepare()
            systemMessage = "Website filter requested. Approve Fermo in System Settings if macOS asks."
        } catch {
            systemMessage = "Website filter setup: \(Self.describe(error))"
        }
        await refreshPermissions()
    }

    func requestLoginItem() async {
        _ = registerHelperForActiveContractIfPossible()
        await refreshPermissions()
    }

    func requestNotifications() async {
        _ = await permissionsProbe.requestNotifications()
        await refreshPermissions()
    }

    func requestAccessibility() async {
        permissionsProbe.requestAccessibilityPrompt()
        await refreshPermissions()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Self.onboardingDefaultsKey)
    }

    func reopenOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: Self.onboardingDefaultsKey)
    }

    static func filterPermissionState(_ status: WebsiteBlockingStatus) -> PermissionState {
        switch status {
        case .active, .ready: return .satisfied
        case .needsPermission: return .needsApproval
        case .unavailable: return .unavailable
        }
    }

    static func loginPermissionState(_ status: HelperRegistrationStatus) -> PermissionState {
        switch status {
        case .enabled: return .satisfied
        case .requiresApproval: return .needsApproval
        case .notRegistered, .notFound: return .notDetermined
        case .unavailable: return .unavailable
        }
    }

    // MARK: Room / blocklist editing

    func addDomain(_ pattern: String, to blocklistID: UUID) async {
        do {
            let next = try policyEditor.addDomain(pattern, to: blocklistID, in: policy)
            await applyEditedPolicy(next)
            systemMessage = "Blocked \(pattern.trimmingCharacters(in: .whitespacesAndNewlines))."
        } catch {
            systemMessage = "Could not add site: \(Self.describe(error))"
        }
    }

    func removeDomain(_ normalizedPattern: String, from blocklistID: UUID) async {
        do {
            let next = try policyEditor.removeDomain(normalizedPattern: normalizedPattern, from: blocklistID, in: policy)
            await applyEditedPolicy(next)
            systemMessage = "Removed \(normalizedPattern)."
        } catch {
            systemMessage = "Could not remove site: \(Self.describe(error))"
        }
    }

    func addApp(from url: URL, to blocklistID: UUID) async {
        guard let rule = Self.appRule(from: url) else {
            systemMessage = "Could not read a bundle identifier from \(url.lastPathComponent)."
            return
        }
        do {
            let next = try policyEditor.addApp(rule, to: blocklistID, in: policy)
            await applyEditedPolicy(next)
            systemMessage = "Blocked \(rule.displayName)."
        } catch {
            systemMessage = "Could not add app: \(Self.describe(error))"
        }
    }

    func removeApp(_ bundleIdentifier: String, from blocklistID: UUID) async {
        do {
            let next = try policyEditor.removeApp(bundleIdentifier: bundleIdentifier, from: blocklistID, in: policy)
            await applyEditedPolicy(next)
            systemMessage = "Removed \(bundleIdentifier)."
        } catch {
            systemMessage = "Could not remove app: \(Self.describe(error))"
        }
    }

    func createRoom(named name: String) {
        do {
            let next = try policyEditor.createBlocklist(named: name, in: policy)
            policy = next
            _ = try? protectionRuntimeController.persistPolicy(next)
            systemMessage = "Created room \(name.trimmingCharacters(in: .whitespacesAndNewlines))."
        } catch {
            systemMessage = "Could not create room: \(Self.describe(error))"
        }
    }

    func deleteRoom(_ blocklistID: UUID) async {
        do {
            let next = try policyEditor.deleteBlocklist(blocklistID, in: policy)
            await applyEditedPolicy(next)
            systemMessage = "Room deleted."
        } catch {
            systemMessage = "Could not delete room: \(Self.describe(error))"
        }
    }

    func setRoom(_ blocklistID: UUID, enabled: Bool) async {
        do {
            let next = try policyEditor.setBlocklist(blocklistID, enabled: enabled, in: policy)
            await applyEditedPolicy(next)
        } catch {
            systemMessage = "Could not change room: \(Self.describe(error))"
        }
    }

    var isBrowserBundleIdentifier: (String) -> Bool {
        { identifier in Self.knownBrowserBundleIdentifiers.contains(identifier.lowercased()) }
    }

    private func applyEditedPolicy(_ newPolicy: FermoPolicy) async {
        policy = newPolicy
        do {
            try protectionRuntimeController.persistPolicy(newPolicy)
        } catch {
            systemMessage = "Saved locally but could not persist shared state: \(Self.describe(error))"
        }

        if !newPolicy.activeSessions(at: Date()).isEmpty {
            try? await websiteBlockingController.refreshRules(policy: newPolicy)
            interruptProtectedAppsOnce()
        }
    }

    // MARK: Quick Block

    func startQuickBlock(room: Blocklist, duration: TimeInterval, rigor: ContractRigor) async {
        isUpdatingWebsiteFilter = true
        defer { isUpdatingWebsiteFilter = false }

        do {
            let draft = QuickBlockDraft(blocklist: room, duration: duration, rigor: rigor)
            let newPolicy = try draft.activePolicy()
            try await systemExtensionActivationController.activate()
            try await websiteBlockingController.activate(policy: newPolicy)
            policy = newPolicy
            try protectionRuntimeController.persistPolicy(newPolicy)
            startAppInterruptionMonitor()
            let report = interruptProtectedAppsOnce()
            let helperMessage = registerHelperForActiveContractIfPossible()
            websiteBlockingStatus = await websiteBlockingController.status()
            let interruption = report.interruptedApps.isEmpty
                ? "No matching distracting app was running."
                : Self.describe(report)
            systemMessage = "Quick Block '\(room.name)' started. \(interruption) \(helperMessage)"
        } catch {
            websiteBlockingStatus = await websiteBlockingController.status()
            systemMessage = "Quick Block could not start: \(Self.describe(error))"
        }
    }

    // MARK: Evidence export

    func markdown(for entry: EvidenceLogEntry) -> String {
        EvidenceMarkdownRenderer().render(entry)
    }

    func ledgerMarkdown() -> String {
        EvidenceMarkdownRenderer().renderLedger(policy.evidenceLog)
    }

    static func appRule(from url: URL) -> AppRule? {
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else {
            return nil
        }
        let name = url.deletingPathExtension().lastPathComponent
        return AppRule(bundleIdentifier: identifier, displayName: name)
    }

    static let knownBrowserBundleIdentifiers: Set<String> = [
        "com.apple.safari",
        "com.google.chrome",
        "com.google.chrome.canary",
        "org.mozilla.firefox",
        "company.thebrowser.browser", // Arc
        "company.thebrowser.dia", // Dia
        "com.microsoft.edgemac",
        "com.brave.browser",
        "com.operasoftware.opera",
        "com.vivaldi.vivaldi"
    ]
}
