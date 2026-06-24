import Foundation

public struct EvidenceExportDestinationDiagnostic: Equatable, Sendable {
    public enum State: String, Codable, Equatable, Sendable {
        case ready
        case willCreate
        case missingParent
        case notDirectory
        case notWritable
    }

    public var directory: URL
    public var state: State
    public var message: String

    public static func inspect(
        _ directory: URL,
        fileManager: FileManager = .default
    ) -> EvidenceExportDestinationDiagnostic {
        var isDirectory = ObjCBool(false)

        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                return EvidenceExportDestinationDiagnostic(
                    directory: directory,
                    state: .notDirectory,
                    message: "Export path is not a folder."
                )
            }

            guard fileManager.isWritableFile(atPath: directory.path) else {
                return EvidenceExportDestinationDiagnostic(
                    directory: directory,
                    state: .notWritable,
                    message: "Export folder is not writable."
                )
            }

            return EvidenceExportDestinationDiagnostic(
                directory: directory,
                state: .ready,
                message: "Export folder is ready."
            )
        }

        let parent = directory.deletingLastPathComponent()
        var parentIsDirectory = ObjCBool(false)
        let parentExists = fileManager.fileExists(atPath: parent.path, isDirectory: &parentIsDirectory)

        guard parentExists, parentIsDirectory.boolValue, fileManager.isWritableFile(atPath: parent.path) else {
            return EvidenceExportDestinationDiagnostic(
                directory: directory,
                state: .missingParent,
                message: "Export folder cannot be created because its parent is unavailable."
            )
        }

        return EvidenceExportDestinationDiagnostic(
            directory: directory,
            state: .willCreate,
            message: "Export folder will be created on first export."
        )
    }
}

public struct EvidenceMarkdownExporter: Sendable {
    private let renderer: EvidenceMarkdownRenderer

    public init(renderer: EvidenceMarkdownRenderer = EvidenceMarkdownRenderer()) {
        self.renderer = renderer
    }

    public func export(_ entry: EvidenceLogEntry, to directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = availableURL(in: directory, preferredFileName: fileName(for: entry))
        try renderer.render(entry).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public func exportLedger(
        _ entries: [EvidenceLogEntry],
        to directory: URL,
        fileName: String = "Fermo-Evidence-Ledger.md"
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = availableURL(in: directory, preferredFileName: fileName)
        try renderLedger(entries).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public func renderLedger(_ entries: [EvidenceLogEntry]) -> String {
        var lines = [
            "# Fermo Evidence Ledger",
            "",
            "- Entries: \(entries.count)",
            ""
        ]

        for entry in entries.sorted(by: { $0.createdAt > $1.createdAt }) {
            lines.append(contentsOf: [
                "## \(entry.taskTitle)",
                "",
                "- Session ID: `\(entry.sessionID.uuidString)`",
                "- Created: \(ISO8601DateFormatter().string(from: entry.createdAt))",
                "- Outcome: \(entry.outcome.rawValue)",
                "- Mode: \(entry.mode.rawValue)",
                "- Rigor: \(entry.rigor.rawValue)",
                ""
            ])
            lines.append(renderer.render(entry))
        }

        return lines.joined(separator: "\n")
    }

    private func fileName(for entry: EvidenceLogEntry) -> String {
        let date = ISO8601DateFormatter()
            .string(from: entry.createdAt)
            .replacingOccurrences(of: ":", with: "-")
        let title = sanitizedFileComponent(entry.taskTitle)
        return "\(date)-\(title)-\(entry.id.uuidString.prefix(8)).md"
    }

    private func availableURL(in directory: URL, preferredFileName: String) -> URL {
        let preferredURL = directory.appendingPathComponent(preferredFileName)
        guard FileManager.default.fileExists(atPath: preferredURL.path) else {
            return preferredURL
        }

        let baseName = preferredURL.deletingPathExtension().lastPathComponent
        let fileExtension = preferredURL.pathExtension

        for index in 2...9_999 {
            let candidateName = fileExtension.isEmpty
                ? "\(baseName)-\(index)"
                : "\(baseName)-\(index).\(fileExtension)"
            let candidateURL = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        // Numbered range exhausted (pathological); fall back to a globally-unique suffix
        // so the export still cannot overwrite an existing ledger file.
        let uniqueName = fileExtension.isEmpty
            ? "\(baseName)-\(UUID().uuidString)"
            : "\(baseName)-\(UUID().uuidString).\(fileExtension)"
        return directory.appendingPathComponent(uniqueName)
    }

    private func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars)
            .replacingOccurrences(of: " ", with: "-")
            .split(separator: "-")
            .joined(separator: "-")
        return collapsed.isEmpty ? "evidence" : collapsed
    }
}
