import FermoCore
import SwiftUI

struct FermoEvidenceView: View {
    @ObservedObject var model: FermoViewModel
    var onStartContract: () -> Void = {}

    @State private var outcomeFilter: EvidenceOutcome?
    @State private var rigorFilter: ContractRigor?

    private var entries: [EvidenceLogEntry] {
        model.policy.evidenceLog.reversed().filter { entry in
            (outcomeFilter == nil || entry.outcome == outcomeFilter)
                && (rigorFilter == nil || entry.rigor == rigorFilter)
        }
    }

    var body: some View {
        FermoScreen(
            title: "Evidence",
            subtitle: "A local Markdown ledger for the contract you actually ran."
        ) {
            if let session = model.currentContractSession {
                if session.isActive(at: Date()), session.rigor != .soft {
                    FermoBreakGlassPanel(model: model, session: session)
                } else {
                    FermoProofCapturePanel(model: model, session: session)
                }
            }

            if model.policy.evidenceLog.isEmpty {
                FermoEmptyStateCard(
                    symbol: "list.bullet.clipboard",
                    tone: .muted,
                    title: "Evidence log is empty",
                    message: "Sessions write a small Markdown file each. Once you have a few, this becomes a calm, searchable work ledger — kept locally on this Mac.",
                    illustrationLabel: "Evidence · empty",
                    primaryTitle: "Start a contract",
                    primaryAction: onStartContract
                )
            } else {
                FermoPanel("Ledger", subtitle: summaryLine, symbol: "list.bullet.clipboard") {
                    VStack(alignment: .leading, spacing: 12) {
                        filterBar
                        if entries.isEmpty {
                            Text("No entries match the current filter.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(entries) { entry in
                                    EvidenceLogRow(entry: entry)
                                    if entry.id != entries.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                        Divider()
                        evidenceFooter
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                FermoFilterPill(label: "All outcomes", isActive: outcomeFilter == nil) { outcomeFilter = nil }
                ForEach(EvidenceOutcome.allCases, id: \.self) { value in
                    FermoFilterPill(label: value.displayName, isActive: outcomeFilter == value) {
                        outcomeFilter = outcomeFilter == value ? nil : value
                    }
                }
            }
            HStack(spacing: 6) {
                FermoFilterPill(label: "Any rigor", isActive: rigorFilter == nil) { rigorFilter = nil }
                ForEach(ContractRigor.allCases, id: \.self) { value in
                    FermoFilterPill(label: value.displayName, isActive: rigorFilter == value) {
                        rigorFilter = rigorFilter == value ? nil : value
                    }
                }
            }
        }
    }

    private var summaryLine: String {
        let shown = entries
        let minutes = shown.reduce(0) { $0 + Int(($1.endedAt.timeIntervalSince($1.startedAt) / 60).rounded()) }
        let withProof = shown.filter { entry in
            entry.artifacts.contains { artifact in
                switch artifact {
                case .note, .filePath, .commitHash, .screenshotPath: true
                case .notDoneReason, .breakGlassReason: false
                }
            }
        }.count
        let broke = shown.filter { $0.outcome == .breakGlass }.count
        let notDone = shown.filter { $0.outcome == .notCompleted }.count
        return "\(shown.count) sessions · \(minutes) min of focus · \(withProof) with proof · \(broke) broke-glass · \(notDone) not done"
    }

    private var evidenceFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder").foregroundStyle(.secondary)
            Text(model.evidenceExportDirectoryDescription)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button {
                model.revealEvidenceFolder()
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            Menu {
                Button("Copy latest entry") { model.copyLatestEvidenceMarkdown() }
                Button("Copy full ledger") { model.copyEvidenceLedgerMarkdown() }
                Divider()
                Button("Export latest file") { model.exportLatestEvidence() }
                Button("Export ledger file") { model.exportEvidenceLedger() }
            } label: {
                Label("Copy as Markdown", systemImage: "doc.on.doc")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

struct FermoProofCapturePanel: View {
    @ObservedObject var model: FermoViewModel
    let session: FocusSession
    @State private var outcome = EvidenceOutcome.completed
    @State private var note = ""
    @State private var filePath = ""
    @State private var commitHash = ""
    @State private var notDoneReason = ""
    @State private var nextStep = ""

    // Break glass has its own deliberate-friction modal, so the proof picker only offers the
    // normal completion outcomes here.
    private static let pickableOutcomes: [EvidenceOutcome] = [.completed, .partiallyCompleted, .notCompleted]

    private var currentDraft: EvidenceDraft {
        EvidenceDraft(
            outcome: outcome,
            note: note,
            filePath: filePath,
            commitHash: commitHash,
            notDoneReason: notDoneReason,
            nextStep: nextStep
        )
    }

    var body: some View {
        FermoPanel(
            "Record Proof",
            subtitle: "Locked and Emergency contracts need the timer to finish; break glass has its own confirm.",
            symbol: "checkmark.seal"
        ) {
            HStack(alignment: .top, spacing: 14) {
                formColumn
                FermoMarkdownPreview(
                    filename: previewFilename,
                    markdown: model.proofPreviewMarkdown(for: session, draft: currentDraft)
                )
                .frame(maxWidth: 360)
            }
        }
    }

    private var formColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            ActiveContractSummary(session: session)

            if let required = session.contract?.requiredProof {
                Text("This contract asked for: \(required.displayName) — \(required.detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                ForEach(Self.pickableOutcomes, id: \.self) { value in
                    FermoSelectableCard(
                        symbol: value.symbol,
                        title: value.displayName,
                        detail: value.captureDescription,
                        isSelected: outcome == value,
                        tone: value.tone
                    ) {
                        outcome = value
                    }
                }
            }

            TextField("Proof note", text: $note, axis: .vertical)
                .lineLimit(2...5)
            HStack {
                TextField("File path", text: $filePath)
                TextField("Commit hash", text: $commitHash)
            }
            if outcome == .notCompleted {
                TextField("Reason not completed", text: $notDoneReason, axis: .vertical)
                    .lineLimit(2...4)
            }
            TextField("Next step", text: $nextStep)

            Button {
                record()
            } label: {
                Label("Record Evidence", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(FermoTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewFilename: String {
        let base = (session.contract?.taskTitle ?? session.title)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return base.isEmpty ? "evidence.md" : "\(base).md"
    }

    private func record() {
        Task {
            await model.recordEvidence(currentDraft)
            note = ""
            filePath = ""
            commitHash = ""
            notDoneReason = ""
            nextStep = ""
        }
    }
}

struct EvidenceLogRow: View {
    let entry: EvidenceLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.outcome == .breakGlass ? "exclamationmark.triangle" : "doc.text")
                .foregroundStyle(entry.outcome.tone.color)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.taskTitle)
                    .font(.subheadline.weight(.semibold))
                Text(entry.intendedOutcome)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(entry.startedAt.formatted(date: .omitted, time: .shortened))-\(entry.endedAt.formatted(date: .omitted, time: .shortened)) · \(entry.mode.displayName) · \(entry.rigor.displayName)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            FermoStatusBadge(label: entry.outcome.displayName, tone: entry.outcome.tone)
        }
        .padding(.vertical, 4)
    }
}

struct EvidencePreviewRow: View {
    let task: String
    let outcome: String
    let proof: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text")
                .foregroundStyle(FermoTheme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(task)
                    .font(.subheadline.weight(.semibold))
                Text(proof)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            FermoStatusBadge(label: outcome, tone: outcome == "completed" ? .ok : .warning)
        }
        .padding(.vertical, 4)
    }
}

extension FocusMode {
    var displayName: String {
        switch self {
        case .blocklist: "Blocklist"
        case .focusRoom: "Focus Room"
        }
    }

    var symbol: String {
        switch self {
        case .blocklist: "minus.circle"
        case .focusRoom: "door.left.hand.closed"
        }
    }
}

extension ContractRigor {
    var displayName: String {
        switch self {
        case .soft: "Soft"
        case .locked: "Locked"
        case .emergency: "Emergency"
        }
    }

    var symbol: String {
        switch self {
        case .soft: "hand.raised"
        case .locked: "lock.fill"
        case .emergency: "exclamationmark.triangle.fill"
        }
    }
}

extension EvidenceOutcome {
    var displayName: String {
        switch self {
        case .completed: "Completed"
        case .partiallyCompleted: "Partial"
        case .notCompleted: "Not done"
        case .breakGlass: "Break glass"
        }
    }

    var tone: FermoStatusBadge.Tone {
        switch self {
        case .completed: .ok
        case .partiallyCompleted: .warning
        case .notCompleted: .muted
        case .breakGlass: .danger
        }
    }

    var symbol: String {
        switch self {
        case .completed: "checkmark.circle.fill"
        case .partiallyCompleted: "circle.lefthalf.filled"
        case .notCompleted: "xmark.circle"
        case .breakGlass: "exclamationmark.triangle"
        }
    }

    var captureDescription: String {
        switch self {
        case .completed: "Shipped what I planned."
        case .partiallyCompleted: "Some of it landed."
        case .notCompleted: "Did not ship."
        case .breakGlass: "Broke the contract early."
        }
    }
}
