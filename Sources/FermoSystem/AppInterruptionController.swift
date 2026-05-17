import Foundation

#if canImport(AppKit)
import AppKit
#endif

public struct InterruptedApp: Equatable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let terminated: Bool

    public init(bundleIdentifier: String, displayName: String, terminated: Bool) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.terminated = terminated
    }
}

public struct AppInterruptionController: Sendable {
    public init() {}

    public func interruptRunningApps(bundleIdentifiers: Set<String>) -> [InterruptedApp] {
        #if canImport(AppKit)
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard let bundleIdentifier = app.bundleIdentifier,
                  bundleIdentifiers.contains(bundleIdentifier)
            else {
                return nil
            }

            return InterruptedApp(
                bundleIdentifier: bundleIdentifier,
                displayName: app.localizedName ?? bundleIdentifier,
                terminated: app.terminate()
            )
        }
        #else
        []
        #endif
    }
}
