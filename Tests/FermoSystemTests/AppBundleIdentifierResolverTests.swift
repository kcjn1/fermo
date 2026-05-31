import FermoSystem
import Foundation
import Testing

@Test
func resolverFindsAppBundleForStandardExecutablePath() {
    #expect(
        AppBundleIdentifierResolver.appBundlePath(
            forExecutablePath: "/Applications/Discord.app/Contents/MacOS/Discord"
        ) == "/Applications/Discord.app"
    )
}

@Test
func resolverFindsInnermostAppBundleForNestedHelper() {
    #expect(
        AppBundleIdentifierResolver.appBundlePath(
            forExecutablePath: "/Applications/Discord.app/Contents/Frameworks/Discord Helper.app/Contents/MacOS/Discord Helper"
        ) == "/Applications/Discord.app/Contents/Frameworks/Discord Helper.app"
    )
}

@Test
func resolverReturnsNilForExecutableOutsideAppBundle() {
    #expect(AppBundleIdentifierResolver.appBundlePath(forExecutablePath: "/usr/bin/env") == nil)
    #expect(AppBundleIdentifierResolver.appBundlePath(forExecutablePath: "  ") == nil)
    #expect(AppBundleIdentifierResolver.bundleIdentifier(forExecutablePath: "/usr/bin/env") == nil)
}
