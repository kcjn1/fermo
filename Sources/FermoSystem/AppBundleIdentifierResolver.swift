import Foundation

/// Resolves the `CFBundleIdentifier` for a launching executable.
///
/// Endpoint Security reports a process's code-signing `signing_id` and executable path, but
/// Fermo policy is authored against `CFBundleIdentifier` values (e.g. `com.hnc.Discord`).
/// The two are not guaranteed to match, so the App Guard extension resolves the real bundle
/// identifier from the executable's enclosing `.app` before asking `AppEnforcementPolicy` to
/// decide. The path-walking step is pure and unit-tested; reading the bundle identifier is a
/// thin wrapper over `Bundle`.
public enum AppBundleIdentifierResolver {
    /// Returns the innermost enclosing `.app` bundle path for an executable path, if any.
    ///
    /// `/Applications/Discord.app/Contents/MacOS/Discord` -> `/Applications/Discord.app`
    public static func appBundlePath(forExecutablePath executablePath: String) -> String? {
        let trimmed = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let components = trimmed.components(separatedBy: "/")
        guard let appIndex = components.lastIndex(where: { $0.count > 4 && $0.hasSuffix(".app") }) else {
            return nil
        }

        return components[...appIndex].joined(separator: "/")
    }

    /// Resolves the `CFBundleIdentifier` for an executable by reading its enclosing app bundle.
    /// Returns `nil` when the executable is not inside an app bundle or the bundle has no id.
    public static func bundleIdentifier(forExecutablePath executablePath: String) -> String? {
        guard let appBundlePath = appBundlePath(forExecutablePath: executablePath) else { return nil }
        return Bundle(url: URL(fileURLWithPath: appBundlePath))?.bundleIdentifier
    }
}
