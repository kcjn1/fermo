import FermoCore
import Foundation
import Testing

@Test
func evidenceExporterWritesSingleEntryMarkdownFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoEvidenceExportTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let entry = sampleEvidenceEntry(taskTitle: "Ship / Fermo: beta?")
    let url = try EvidenceMarkdownExporter().export(entry, to: directory)
    let markdown = try String(contentsOf: url, encoding: .utf8)

    #expect(url.lastPathComponent.hasSuffix(".md"))
    #expect(url.lastPathComponent.contains("Ship-Fermo-beta"))
    #expect(markdown.contains("# Ship / Fermo: beta?"))
    #expect(markdown.contains("- Session ID: `\(entry.sessionID.uuidString)`"))
}

@Test
func evidenceExporterDoesNotOverwriteExistingSingleEntryExport() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoEvidenceCollisionTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let entry = sampleEvidenceEntry(taskTitle: "Collision check")
    let exporter = EvidenceMarkdownExporter()
    let firstURL = try exporter.export(entry, to: directory)
    let secondURL = try exporter.export(entry, to: directory)

    #expect(firstURL != secondURL)
    #expect(FileManager.default.fileExists(atPath: firstURL.path))
    #expect(FileManager.default.fileExists(atPath: secondURL.path))
    #expect(secondURL.deletingPathExtension().lastPathComponent.hasSuffix("-2"))
}

@Test
func evidenceExporterWritesLedgerMarkdownFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoEvidenceLedgerExportTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = sampleEvidenceEntry(taskTitle: "First session")
    let second = sampleEvidenceEntry(taskTitle: "Second session")
    let url = try EvidenceMarkdownExporter().exportLedger([first, second], to: directory)
    let markdown = try String(contentsOf: url, encoding: .utf8)

    #expect(url.lastPathComponent == "Fermo-Evidence-Ledger.md")
    #expect(markdown.contains("# Fermo Evidence Ledger"))
    #expect(markdown.contains("## First session"))
    #expect(markdown.contains("## Second session"))
}

@Test
func evidenceExporterDoesNotOverwriteExistingLedgerExport() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoEvidenceLedgerCollisionTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let entry = sampleEvidenceEntry(taskTitle: "Ledger collision")
    let exporter = EvidenceMarkdownExporter()
    let firstURL = try exporter.exportLedger([entry], to: directory)
    let secondURL = try exporter.exportLedger([entry], to: directory)

    #expect(firstURL.lastPathComponent == "Fermo-Evidence-Ledger.md")
    #expect(secondURL.lastPathComponent == "Fermo-Evidence-Ledger-2.md")
    #expect(FileManager.default.fileExists(atPath: firstURL.path))
    #expect(FileManager.default.fileExists(atPath: secondURL.path))
}

@Test
func evidenceExportDestinationDiagnosticReportsReadyDirectory() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoEvidenceDestinationReadyTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let diagnostic = EvidenceExportDestinationDiagnostic.inspect(directory)

    #expect(diagnostic.state == .ready)
    #expect(diagnostic.message.contains("ready"))
}

@Test
func evidenceExportDestinationDiagnosticReportsFileInsteadOfDirectory() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoEvidenceDestinationFileTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("not-a-folder")
    try "nope".write(to: fileURL, atomically: true, encoding: .utf8)

    let diagnostic = EvidenceExportDestinationDiagnostic.inspect(fileURL)

    #expect(diagnostic.state == .notDirectory)
    #expect(diagnostic.message.contains("not a folder"))
}

@Test
func fermoSnapshotRoundTripsEvidenceExportPreference() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoPreferencesStoreTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent(JSONFileFermoStore.defaultFileName)
    let preferences = FermoPreferences(evidenceExportDirectoryPath: "/tmp/Fermo Evidence")

    try JSONFileFermoStore(url: url).save(FermoSnapshot(preferences: preferences))
    let loaded = try JSONFileFermoStore(url: url).load()

    #expect(loaded.preferences == preferences)
}

@Test
func fermoSnapshotRoundTripsContractDefaultPreferences() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FermoContractDefaultsStoreTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent(JSONFileFermoStore.defaultFileName)
    let preferences = FermoPreferences(
        evidenceExportDirectoryPath: nil,
        defaultPresetID: "planning",
        defaultRigor: .emergency,
        defaultDurationMinutes: 55
    )

    try JSONFileFermoStore(url: url).save(FermoSnapshot(preferences: preferences))
    let loaded = try JSONFileFermoStore(url: url).load()

    #expect(loaded.preferences == preferences)
    #expect(loaded.preferences.defaultPresetID == "planning")
    #expect(loaded.preferences.defaultRigor == .emergency)
    #expect(loaded.preferences.defaultDurationMinutes == 55)
}

@Test
func fermoSnapshotDecodesOlderPreferencesWithoutContractDefaults() throws {
    let json = """
    {
      "blocklists": [],
      "sessions": [],
      "schedules": [],
      "evidenceLog": [],
      "preferences": {
        "evidenceExportDirectoryPath": "/tmp/Fermo Evidence"
      }
    }
    """
    let data = try #require(json.data(using: .utf8))

    let snapshot = try JSONDecoder().decode(FermoSnapshot.self, from: data)

    #expect(snapshot.preferences.evidenceExportDirectoryPath == "/tmp/Fermo Evidence")
    #expect(snapshot.preferences.defaultPresetID == nil)
    #expect(snapshot.preferences.defaultRigor == .locked)
    #expect(snapshot.preferences.defaultDurationMinutes == 90)
}

private func sampleEvidenceEntry(taskTitle: String) -> EvidenceLogEntry {
    let startedAt = Date(timeIntervalSince1970: 1_800_000)
    return EvidenceLogEntry(
        sessionID: UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!,
        createdAt: startedAt.addingTimeInterval(3_600),
        taskTitle: taskTitle,
        intendedOutcome: "A useful artifact exists.",
        outcome: .completed,
        mode: .blocklist,
        rigor: .locked,
        startedAt: startedAt,
        endedAt: startedAt.addingTimeInterval(3_600),
        blockedDomains: ["reddit.com"],
        blockedApps: ["com.hnc.Discord"],
        artifacts: [.note("Done.")]
    )
}
