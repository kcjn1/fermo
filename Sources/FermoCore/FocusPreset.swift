import Foundation

public struct FocusPreset: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var mode: FocusMode
    public var suggestedRigor: ContractRigor
    public var blockedDomains: [DomainRule]
    public var blockedApps: [AppRule]
    public var allowedDomains: [DomainRule]
    public var allowedApps: [AppRule]

    public init(
        id: String,
        name: String,
        mode: FocusMode,
        suggestedRigor: ContractRigor,
        blockedDomains: [DomainRule],
        blockedApps: [AppRule] = [],
        allowedDomains: [DomainRule] = [],
        allowedApps: [AppRule] = []
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.suggestedRigor = suggestedRigor
        self.blockedDomains = blockedDomains
        self.blockedApps = blockedApps
        self.allowedDomains = allowedDomains
        self.allowedApps = allowedApps
    }
}

public enum FocusPresetLibrary {
    public static func defaults() throws -> [FocusPreset] {
        [
            FocusPreset(
                id: "writing",
                name: "Writing",
                mode: .focusRoom,
                suggestedRigor: .locked,
                blockedDomains: try commonDistractions(),
                allowedDomains: [
                    try DomainRule("docs.google.com"),
                    try DomainRule("obsidian.md")
                ],
                allowedApps: [
                    AppRule(bundleIdentifier: "md.obsidian", displayName: "Obsidian"),
                    AppRule(bundleIdentifier: "com.apple.TextEdit", displayName: "TextEdit")
                ]
            ),
            FocusPreset(
                id: "coding",
                name: "Coding",
                mode: .focusRoom,
                suggestedRigor: .locked,
                blockedDomains: try commonDistractions(),
                allowedDomains: [
                    try DomainRule("developer.apple.com"),
                    try DomainRule("github.com"),
                    try DomainRule("stackoverflow.com")
                ],
                allowedApps: [
                    AppRule(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode"),
                    AppRule(bundleIdentifier: "com.apple.Terminal", displayName: "Terminal"),
                    AppRule(bundleIdentifier: "com.todesktop.230313mzl4w4u92", displayName: "Cursor")
                ]
            ),
            FocusPreset(
                id: "admin",
                name: "Admin",
                mode: .blocklist,
                suggestedRigor: .soft,
                blockedDomains: try commonDistractions(),
                allowedDomains: [
                    try DomainRule("calendar.google.com"),
                    try DomainRule("mail.google.com")
                ]
            ),
            FocusPreset(
                id: "deep-planning",
                name: "Deep Planning",
                mode: .focusRoom,
                suggestedRigor: .emergency,
                blockedDomains: try commonDistractions(),
                allowedDomains: [
                    try DomainRule("github.com"),
                    try DomainRule("developer.apple.com"),
                    try DomainRule("docs.anthropic.com"),
                    try DomainRule("platform.openai.com")
                ],
                allowedApps: [
                    AppRule(bundleIdentifier: "md.obsidian", displayName: "Obsidian"),
                    AppRule(bundleIdentifier: "com.apple.Terminal", displayName: "Terminal")
                ]
            )
        ]
    }

    private static func commonDistractions() throws -> [DomainRule] {
        [
            try DomainRule("youtube.com"),
            try DomainRule("reddit.com"),
            try DomainRule("x.com"),
            try DomainRule("facebook.com"),
            try DomainRule("instagram.com"),
            try DomainRule("tiktok.com"),
            try DomainRule("netflix.com")
        ]
    }
}
