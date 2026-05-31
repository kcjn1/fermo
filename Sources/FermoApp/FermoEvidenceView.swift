import FermoCore
import SwiftUI

struct FermoEvidenceView: View {
    @ObservedObject var model: FermoViewModel

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

            FermoPanel("Ledger", subtitle: "\(model.policy.evidenceLog.count) local entries", symbol: "list.bullet.clipboard") {
                let entries = Array(model.policy.evidenceLog.reversed())
                if entries.isEmpty {
                    Text("No evidence recorded yet. Complete a contract, attach proof, or use break glass with a reason.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button {
                                model.exportLatestEvidence()
                            } label: {
                                Label("Export Latest", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FermoTheme.accent)

                            Button {
                                model.exportEvidenceLedger()
                            } label: {
                                Label("Export Ledger", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                        }

                        ForEach(entries) { entry in
                            EvidenceLogRow(entry: entry)
                            if entry.id != entries.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }

            if let markdown = model.latestEvidenceMarkdown {
                FermoPanel("Latest Markdown Preview", symbol: "doc.plaintext") {
                    ScrollView(.horizontal) {
                        Text(markdown)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
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
    @State private var breakGlassReason = ""
    @State private var nextStep = ""

    var body: some View {
        FermoPanel(
            "Record Proof",
            subtitle: "Locked and Emergency contracts need the timer to finish, unless you record break glass.",
            symbol: "checkmark.seal"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ActiveContractSummary(session: session)

                Picker("Outcome", selection: $outcome) {
                    ForEach(EvidenceOutcome.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)

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
                if outcome == .breakGlass {
                    TextField("Break-glass reason", text: $breakGlassReason, axis: .vertical)
                        .lineLimit(2...4)
                }
                TextField("Next step", text: $nextStep)

                Button {
                    record()
                } label: {
                    Label(outcome == .breakGlass ? "Break Glass and Record" : "Record Evidence", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(outcome == .breakGlass ? FermoTheme.warning : FermoTheme.accent)
            }
        }
    }

    private func record() {
        Task {
            await model.recordEvidence(
                EvidenceDraft(
                    outcome: outcome,
                    note: note,
                    filePath: filePath,
                    commitHash: commitHash,
                    notDoneReason: notDoneReason,
                    breakGlassReason: breakGlassReason,
                    nextStep: nextStep
                )
            )
            note = ""
            filePath = ""
            commitHash = ""
            notDoneReason = ""
            breakGlassReason = ""
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
}

extension ContractRigor {
    var displayName: String {
        switch self {
        case .soft: "Soft"
        case .locked: "Locked"
        case .emergency: "Emergency"
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
}
