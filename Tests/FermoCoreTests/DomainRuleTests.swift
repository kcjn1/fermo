import FermoCore
import Testing

@Test
func exactDomainRuleMatchesBaseDomainAndSubdomains() throws {
    let rule = try DomainRule("youtube.com")

    #expect(rule.matches(host: "youtube.com"))
    #expect(rule.matches(host: "www.youtube.com"))
    #expect(rule.matches(host: "music.youtube.com"))
    #expect(!rule.matches(host: "notyoutube.com"))
}

@Test
func wildcardDomainRuleRequiresSubdomain() throws {
    let rule = try DomainRule("*.reddit.com")

    #expect(!rule.matches(host: "reddit.com"))
    #expect(rule.matches(host: "old.reddit.com"))
    #expect(rule.matches(host: "www.reddit.com"))
}

@Test
func domainRuleNormalizesUrlsAndPorts() throws {
    let rule = try DomainRule("https://x.com/home")

    #expect(rule.normalizedPattern == "x.com")
    #expect(rule.matches(host: "https://www.x.com:443/some/path"))
}
