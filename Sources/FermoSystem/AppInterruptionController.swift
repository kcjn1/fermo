import FermoCore
import Foundation

#if canImport(AppKit)
import AppKit
#endif

public enum AppInterruptionOutcome: String, Codable, Equatable, Sendable {
    case terminateRequested
    case terminateFailed
    case signalTerminateRequested
    case signalTerminateFailed
    case forceTerminateRequested
    case forceTerminateFailed
    case skippedCurrentApp
}

public struct InterruptedApp: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let processIdentifier: Int32?
    public let terminated: Bool
    public let outcome: AppInterruptionOutcome

    public init(
        bundleIdentifier: String,
        displayName: String,
        processIdentifier: Int32? = nil,
        terminated: Bool,
        outcome: AppInterruptionOutcome
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.processIdentifier = processIdentifier
        self.terminated = terminated
        self.outcome = outcome
    }
}

public struct AppInterruptionReport: Equatable, Sendable {
    public let requestedBundleIdentifiers: Set<String>
    public let interruptedApps: [InterruptedApp]
    public let observedAt: Date

    public init(
        requestedBundleIdentifiers: Set<String>,
        interruptedApps: [InterruptedApp],
        observedAt: Date = Date()
    ) {
        self.requestedBundleIdentifiers = requestedBundleIdentifiers
        self.interruptedApps = interruptedApps
        self.observedAt = observedAt
    }

    public var matchedBundleIdentifiers: Set<String> {
        Set(interruptedApps.map(\.bundleIdentifier))
    }

    public var missingBundleIdentifiers: Set<String> {
        requestedBundleIdentifiers.subtracting(matchedBundleIdentifiers)
    }

    public var requiresStrongerHandling: Bool {
        interruptedApps.contains { !$0.terminated }
    }

    public var neededForceTermination: Bool {
        interruptedApps.contains {
            $0.outcome == .forceTerminateRequested || $0.outcome == .forceTerminateFailed
        }
    }

    public var neededSignalTermination: Bool {
        interruptedApps.contains {
            $0.outcome == .signalTerminateRequested || $0.outcome == .signalTerminateFailed
        }
    }

    public var attemptedTerminationCount: Int {
        interruptedApps.filter { $0.outcome == .terminateRequested }.count
    }

    public var attemptedSignalTerminationCount: Int {
        interruptedApps.filter { $0.outcome == .signalTerminateRequested }.count
    }

    public var attemptedForceTerminationCount: Int {
        interruptedApps.filter { $0.outcome == .forceTerminateRequested }.count
    }
}

public struct AppInterruptionController: Sendable {
    public static let defaultFocusRoomExcludedBundleIdentifiers: Set<String> = [
        "com.toolary.fermo",
        "com.toolary.fermo.helper",
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.loginwindow",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.WindowManager",
        "com.apple.Spotlight"
    ]

    public init() {}

    public func interruptRunningApps(bundleIdentifiers: Set<String>) -> [InterruptedApp] {
        interruptRunningAppsReport(bundleIdentifiers: bundleIdentifiers).interruptedApps
    }

    public func interruptPolicyViolatingAppsReport(
        policy: FermoPolicy,
        at date: Date = Date(),
        currentBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        excludedBundleIdentifiers: Set<String> = Self.defaultFocusRoomExcludedBundleIdentifiers,
        signalAfterGracefulFailure: Bool = false,
        forceTerminateAfterGracefulFailure: Bool = false
    ) -> AppInterruptionReport {
        let bundleIdentifiers: Set<String>

        #if canImport(AppKit)
        let runningBundleIdentifiers = Set(Self.runningApplicationCandidates(for: []).compactMap { app -> String? in
            guard app.activationPolicy == .regular else { return nil }
            return app.bundleIdentifier
        })
        bundleIdentifiers = Self.policyViolationBundleIdentifiers(
            policy: policy,
            runningBundleIdentifiers: runningBundleIdentifiers,
            at: date,
            currentBundleIdentifier: currentBundleIdentifier,
            excludedBundleIdentifiers: excludedBundleIdentifiers
        )
        #else
        bundleIdentifiers = Self.policyViolationBundleIdentifiers(
            policy: policy,
            runningBundleIdentifiers: [],
            at: date,
            currentBundleIdentifier: currentBundleIdentifier,
            excludedBundleIdentifiers: excludedBundleIdentifiers
        )
        #endif

        return interruptRunningAppsReport(
            bundleIdentifiers: bundleIdentifiers,
            currentBundleIdentifier: currentBundleIdentifier,
            signalAfterGracefulFailure: signalAfterGracefulFailure,
            forceTerminateAfterGracefulFailure: forceTerminateAfterGracefulFailure,
            observedAt: date
        )
    }

    public func interruptRunningAppsReport(
        bundleIdentifiers: Set<String>,
        currentBundleIdentifier: String? = Bundle.main.bundleIdentifier,
        signalAfterGracefulFailure: Bool = false,
        forceTerminateAfterGracefulFailure: Bool = false,
        observedAt: Date = Date()
    ) -> AppInterruptionReport {
        let requestedBundleIdentifiers = Self.normalizedBundleIdentifiers(bundleIdentifiers)

        #if canImport(AppKit)
        let interruptedApps = Self.runningApplicationCandidates(
            for: requestedBundleIdentifiers
        ).compactMap { app -> InterruptedApp? in
            guard let bundleIdentifier = app.bundleIdentifier,
                  requestedBundleIdentifiers.contains(bundleIdentifier)
            else {
                return nil
            }

            if bundleIdentifier == currentBundleIdentifier {
                return InterruptedApp(
                    bundleIdentifier: bundleIdentifier,
                    displayName: app.localizedName ?? bundleIdentifier,
                    processIdentifier: app.processIdentifier,
                    terminated: false,
                    outcome: .skippedCurrentApp
                )
            }

            let terminated = app.terminate()
            if !terminated && signalAfterGracefulFailure {
                let signalSent = Darwin.kill(app.processIdentifier, SIGTERM) == 0
                return InterruptedApp(
                    bundleIdentifier: bundleIdentifier,
                    displayName: app.localizedName ?? bundleIdentifier,
                    processIdentifier: app.processIdentifier,
                    terminated: signalSent,
                    outcome: signalSent ? .signalTerminateRequested : .signalTerminateFailed
                )
            }

            if !terminated && forceTerminateAfterGracefulFailure {
                let forceTerminated = app.forceTerminate()
                return InterruptedApp(
                    bundleIdentifier: bundleIdentifier,
                    displayName: app.localizedName ?? bundleIdentifier,
                    processIdentifier: app.processIdentifier,
                    terminated: forceTerminated,
                    outcome: forceTerminated ? .forceTerminateRequested : .forceTerminateFailed
                )
            }

            return InterruptedApp(
                bundleIdentifier: bundleIdentifier,
                displayName: app.localizedName ?? bundleIdentifier,
                processIdentifier: app.processIdentifier,
                terminated: terminated,
                outcome: terminated ? .terminateRequested : .terminateFailed
            )
        }
        #else
        let interruptedApps: [InterruptedApp] = []
        #endif

        return AppInterruptionReport(
            requestedBundleIdentifiers: requestedBundleIdentifiers,
            interruptedApps: interruptedApps,
            observedAt: observedAt
        )
    }

    public static func normalizedBundleIdentifiers(_ bundleIdentifiers: Set<String>) -> Set<String> {
        Set(bundleIdentifiers.compactMap { identifier in
            let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        })
    }

    public static func policyViolationBundleIdentifiers(
        policy: FermoPolicy,
        runningBundleIdentifiers: Set<String>,
        at date: Date = Date(),
        currentBundleIdentifier: String? = nil,
        excludedBundleIdentifiers: Set<String> = Self.defaultFocusRoomExcludedBundleIdentifiers
    ) -> Set<String> {
        var excluded = normalizedBundleIdentifiers(excludedBundleIdentifiers)
        if let currentBundleIdentifier {
            excluded.formUnion(normalizedBundleIdentifiers([currentBundleIdentifier]))
        }

        let enforcementPolicy = AppEnforcementPolicy(alwaysAllowedBundleIdentifiers: excluded)
        let candidates: Set<String>
        if policy.activeSessions(at: date).contains(where: { $0.contract?.isFocusRoom == true }) {
            candidates = normalizedBundleIdentifiers(runningBundleIdentifiers)
        } else {
            candidates = policy.blockedAppBundleIdentifiers(at: date)
        }

        return candidates.filter { bundleIdentifier in
            let decision = enforcementPolicy.decision(
                for: AppLaunchContext(bundleIdentifier: bundleIdentifier),
                policy: policy,
                at: date
            )
            return !decision.shouldAllowLaunch
        }
    }

    #if canImport(AppKit)
    private static func runningApplicationCandidates(for bundleIdentifiers: Set<String>) -> [NSRunningApplication] {
        var candidatesByProcessIdentifier: [pid_t: NSRunningApplication] = [:]

        for app in NSWorkspace.shared.runningApplications {
            candidatesByProcessIdentifier[app.processIdentifier] = app
        }

        for bundleIdentifier in bundleIdentifiers {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier) {
                candidatesByProcessIdentifier[app.processIdentifier] = app
            }
        }

        return Array(candidatesByProcessIdentifier.values)
    }
    #endif
}
