import FermoCore
import Foundation
import Testing

@Test
func fermoSnapshotProjectsToAndFromPolicy() throws {
    let now = Date(timeIntervalSince1970: 70_000)
    let policy = try FermoSampleData.helperPersistenceSpikePolicy(now: now, duration: 900)

    let snapshot = FermoSnapshot(policy: policy)

    #expect(snapshot.policy == policy)
    #expect(snapshot.sessions.first?.isActive(at: now) == true)
    #expect(snapshot.policy.shouldBlock(host: "reddit.com", at: now))
    #expect(snapshot.policy.shouldInterruptApp(bundleIdentifier: "com.apple.calculator", at: now))
}

@Test
func jsonFileFermoStoreRoundTripsHelperPersistenceSnapshot() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("FermoSnapshotStoreTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = JSONFileFermoStore(url: directory.appendingPathComponent(JSONFileFermoStore.defaultFileName))
    let snapshot = FermoSnapshot(
        policy: try FermoSampleData.helperPersistenceSpikePolicy(
            now: Date(timeIntervalSince1970: 70_500),
            duration: 600
        )
    )

    try store.save(snapshot)

    #expect(try store.load() == snapshot)
}

@Test
func focusContractDefaultsRequiredProofWhenAbsentFromLegacyJSON() throws {
    // A session contract persisted before requiredProof existed must still decode.
    let legacyContract = """
    { "taskTitle": "Write", "intendedOutcome": "Ship", "mode": "focusRoom", "rigor": "locked",
      "allowedDomains": [], "allowedApps": [] }
    """
    let contract = try JSONDecoder().decode(FocusContract.self, from: Data(legacyContract.utf8))
    #expect(contract.requiredProof == .markdown)
    #expect(contract.isFocusRoom)
}

@Test
func fermoSnapshotRoundTripsCustomPresetsAndSavedDraft() throws {
    let preset = FocusPreset(
        id: "custom-1",
        name: "My Room",
        mode: .focusRoom,
        suggestedRigor: .locked,
        blockedDomains: [try DomainRule("reddit.com")],
        allowedDomains: [try DomainRule("developer.apple.com")]
    )
    let draft = SavedContractDraft(
        taskTitle: "Resume me",
        intendedOutcome: "Later",
        mode: .blocklist,
        rigor: .soft,
        requiredProof: .fileOrLink,
        durationMinutes: 60,
        blockedDomainPatterns: ["youtube.com"]
    )
    let snapshot = FermoSnapshot(
        policy: FermoPolicy(),
        preferences: FermoPreferences(),
        customPresets: [preset],
        savedDraft: draft
    )
    let data = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(FermoSnapshot.self, from: data)
    #expect(decoded.customPresets == [preset])
    #expect(decoded.savedDraft == draft)
    #expect(decoded.savedDraft?.ruleDraft.blockedDomainPatterns == ["youtube.com"])
}

@Test
func fermoSnapshotDecodesLegacyJSONWithoutCustomPresetsOrDraft() throws {
    let legacyJSON = """
    { "blocklists": [], "sessions": [], "schedules": [], "evidenceLog": [],
      "preferences": { "defaultRigor": "locked", "defaultDurationMinutes": 90 } }
    """
    let decoded = try JSONDecoder().decode(FermoSnapshot.self, from: Data(legacyJSON.utf8))
    #expect(decoded.customPresets.isEmpty)
    #expect(decoded.savedDraft == nil)
}
