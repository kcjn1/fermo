import Foundation

public struct Blocklist: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var domainRules: [DomainRule]
    public var appRules: [AppRule]
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        domainRules: [DomainRule] = [],
        appRules: [AppRule] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.domainRules = domainRules
        self.appRules = appRules
        self.isEnabled = isEnabled
    }
}
