import FermoCore
import SwiftUI

struct FermoTodayView: View {
    @ObservedObject var model: FermoViewModel
    let onStartContract: () -> Void
    let onOpenActive: () -> Void

    var body: some View {
        FermoScreen(
            title: "Today",
            subtitle: "One contract, visible system health, and the next honest action."
        ) {
            FermoStatusStrip(
                label: protectionLabel,
                reason: protectionReason,
                tone: protectionTone,
                actionTitle: statusActionTitle,
                action: statusAction
            )

            if model.currentContractSession == nil {
                if let draft = model.savedDraft {
                    NextContractCard(
                        draft: draft,
                        onEdit: onStartContract,
                        onDiscard: { model.clearSavedDraft() }
                    )
                }
                QuickStartPanel(model: model, onNewPreset: onStartContract)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                FermoPanel("Current Contract", symbol: "target") {
                    if let session = model.currentContractSession {
                        VStack(alignment: .leading, spacing: 12) {
                            ActiveContractSummary(session: session)
                            Button {
                                onOpenActive()
                            } label: {
                                Label("Open Active Session", systemImage: "timer")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FermoTheme.accent)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ready to protect one task.")
                                .font(.title3.weight(.semibold))
                            Text("Choose a preset, write the intended outcome, and start with honest system status visible.")
                                .foregroundStyle(.secondary)
                            Button {
                                onStartContract()
                            } label: {
                                Label("Start Contract", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FermoTheme.accent)
                            .disabled(model.isUpdatingWebsiteFilter)
                        }
                    }
                }

                FermoPanel("Protection Summary", symbol: "lock.shield") {
                    VStack(spacing: 10) {
                        FermoMetric(label: "domains protected", value: "\(model.protectedDomains.count)", symbol: "globe")
                        FermoMetric(label: "apps protected", value: "\(model.protectedApps.count)", symbol: "app.dashed")
                        FermoMetric(label: "helper", value: model.helperStatus.displayName, symbol: "externaldrive", tone: model.helperStatus.tone)
                    }
                }
            }

            FermoPanel("System Health", subtitle: "Local dev checks are wired; signed beta validation is still required.", symbol: "network") {
                VStack(spacing: 0) {
                    ForEach(Array(model.onboardingChecklist.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider()
                        }
                        ProtectionOnboardingRow(item: item)
                    }
                    Divider()
                    FermoHealthRow(title: "App Interruption", detail: model.appInterruptionStatusText, symbol: "app.dashed", tone: model.isAppInterruptionMonitorActive ? .ok : .muted)
                }
            }

            FermoPanel("Recent Evidence", subtitle: "Local proof ledger, rendered as Markdown.", symbol: "list.bullet.clipboard") {
                let entries = Array(model.policy.evidenceLog.suffix(3).reversed())
                if entries.isEmpty {
                    Text("No proof recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(entries) { entry in
                            EvidenceLogRow(entry: entry)
                        }
                    }
                }
            }

            if let systemMessage = model.systemMessage {
                FermoPanel("Last System Message", symbol: "info.circle") {
                    Text(systemMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var protectionLabel: String {
        if model.activeSession != nil { return "Protected" }
        if model.proofDueSession != nil { return "Proof due" }
        if model.websiteBlockingStatus == .active || model.websiteBlockingStatus == .ready { return "Ready" }
        return "Setup needed"
    }

    private var protectionReason: String {
        if let session = model.activeSession {
            return "\(session.rigor.displayName) session in progress. Stop and break-glass behavior depends on the selected rigor."
        }

        if let session = model.proofDueSession {
            return "\(session.contract?.taskTitle ?? session.title) has reached its timer. Record proof to close the contract."
        }

        if model.websiteBlockingStatus == .active || model.websiteBlockingStatus == .ready {
            return "Website protection is available locally. Toolary beta still needs App Guard approval and the signed runtime matrix."
        }

        return "Start a contract to configure website blocking. macOS only prompts on first approval or replacement, so no prompt is expected after approval already exists."
    }

    private var protectionTone: FermoStatusBadge.Tone {
        if model.activeSession != nil { return .ok }
        if model.proofDueSession != nil { return .warning }
        return (model.websiteBlockingStatus == .active || model.websiteBlockingStatus == .ready) ? .ok : .warning
    }

    private var statusActionTitle: String? {
        (model.websiteBlockingStatus == .active || model.websiteBlockingStatus == .ready) ? nil : "Open System Settings"
    }

    private var statusAction: (() -> Void)? {
        statusActionTitle == nil ? nil : { model.openSystemSettings() }
    }
}

struct QuickStartPanel: View {
    @ObservedObject var model: FermoViewModel
    let onNewPreset: () -> Void

    var body: some View {
        FermoPanel("Quick Start", subtitle: "Launch a saved preset in one action.", symbol: "bolt") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 168), spacing: 10)], spacing: 10) {
                    ForEach(model.presets) { preset in
                        Button {
                            Task { await model.startPreset(preset) }
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: preset.mode.symbol)
                                        .foregroundStyle(FermoTheme.accent)
                                    Text(preset.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                HStack(spacing: 6) {
                                    FermoStatusBadge(label: "\(model.preferences.defaultDurationMinutes) min", tone: .muted)
                                    FermoStatusBadge(label: preset.suggestedRigor.displayName, tone: preset.suggestedRigor == .soft ? .muted : .ok)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(FermoTheme.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(FermoTheme.line))
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isUpdatingWebsiteFilter)
                    }
                }
                Button {
                    onNewPreset()
                } label: {
                    Label("New preset", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct NextContractCard: View {
    let draft: SavedContractDraft
    let onEdit: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        FermoPanel("Next Contract · saved draft", symbol: "doc.text") {
            VStack(alignment: .leading, spacing: 12) {
                Text(draft.taskTitle.isEmpty ? "Untitled contract" : draft.taskTitle)
                    .font(.title3.weight(.semibold))
                if !draft.intendedOutcome.isEmpty {
                    Text(draft.intendedOutcome)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    FermoStatusBadge(label: draft.mode.displayName, tone: .info)
                    FermoStatusBadge(label: "\(draft.durationMinutes) min", tone: .muted)
                    FermoStatusBadge(label: draft.rigor.displayName, tone: draft.rigor == .soft ? .muted : .ok)
                    FermoStatusBadge(label: "Proof: \(draft.requiredProof.displayName)", tone: .muted)
                }
                HStack {
                    Button {
                        onEdit()
                    } label: {
                        Label("Resume draft", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FermoTheme.accent)
                    Button {
                        onDiscard()
                    } label: {
                        Label("Discard", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct ActiveContractSummary: View {
    let session: FocusSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.contract?.taskTitle ?? session.title)
                .font(.title3.weight(.semibold))
            if let outcome = session.contract?.intendedOutcome {
                Text(outcome)
                    .foregroundStyle(.secondary)
            }
            HStack {
                FermoStatusBadge(label: session.rigor.displayName, tone: session.rigor == .soft ? .muted : .ok)
                FermoStatusBadge(label: session.contract?.mode.displayName ?? "Blocklist", tone: .info)
                Spacer()
                Text("Ends \(session.endsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FermoActiveSessionView: View {
    @ObservedObject var model: FermoViewModel
    var onStartContract: () -> Void = {}

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            FermoScreen(
                title: "Active Session",
                subtitle: "Timer, enforcement state, rules, proof, and break-glass in one place."
            ) {
                if let session = model.currentContractSession {
                    activeContent(session: session, now: timeline.date)
                } else {
                    FermoEmptyStateCard(
                        symbol: "play.fill",
                        tone: .muted,
                        title: "No active session",
                        message: "You haven't started a contract yet. When you do, this screen turns into a protected workspace with what is being enforced and how much time remains.",
                        illustrationLabel: "Active session · empty",
                        primaryTitle: "Start a contract",
                        primaryAction: onStartContract,
                        secondaryTitle: "Browse presets",
                        secondaryAction: onStartContract
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func activeContent(session: FocusSession, now: Date) -> some View {
        FermoStatusStrip(
            label: statusLabel(for: session, now: now),
            reason: statusReason(for: session, now: now),
            tone: statusTone(for: session, now: now)
        )

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            FermoPanel("Contract Timer", symbol: "timer") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(timeDisplay(for: session, now: now))
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    ActiveContractSummary(session: session)
                    ProgressView(value: progress(for: session, now: now))
                        .tint(FermoTheme.accent)
                }
            }

            FermoPanel("Runtime Health", symbol: "lock.shield") {
                VStack(spacing: 0) {
                    FermoHealthRow(title: "Website Filter", detail: model.websiteBlockingStatus.displayName, symbol: "network", tone: model.websiteBlockingStatus.tone)
                    Divider()
                    FermoHealthRow(title: "App Interruption", detail: model.appInterruptionStatusText, symbol: "app.dashed", tone: model.isAppInterruptionMonitorActive ? .ok : .warning)
                    Divider()
                    FermoHealthRow(title: "Helper", detail: model.helperStatus.displayName, symbol: "externaldrive", tone: model.helperStatus.tone)
                }
            }
        }

        FermoPanel("Rule Boundary", subtitle: session.contract?.mode.displayName ?? "Blocklist", symbol: "scope") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                RuleList(title: "Blocked websites", symbol: "globe", items: model.blockedDomains(for: session))
                RuleList(title: "Blocked apps", symbol: "app.dashed", items: model.blockedApps(for: session))
                RuleList(title: "Allowed websites", symbol: "checkmark.circle", items: model.allowedDomains(for: session))
                RuleList(title: "Allowed apps", symbol: "checkmark.seal", items: model.allowedApps(for: session))
            }
        }

        if let report = model.latestAppInterruptionReport {
            FermoPanel("Last App Interruption Pass", subtitle: report.observedAt.formatted(date: .omitted, time: .standard), symbol: "app.badge.checkmark") {
                VStack(alignment: .leading, spacing: 8) {
                    FermoMetric(label: "requested app targets", value: "\(report.requestedBundleIdentifiers.count)", symbol: "target")
                    FermoMetric(label: "matched running apps", value: "\(report.interruptedApps.count)", symbol: "bolt")
                    if report.requiresStrongerHandling {
                        Text("One or more apps resisted graceful termination. This remains visible because Fermo should not overclaim enforcement.")
                            .font(.caption)
                            .foregroundStyle(FermoTheme.warning)
                    }
                }
            }
        }

        if session.isActive(at: now) {
            if session.rigor == .soft {
                FermoSoftStopPanel(model: model)
                FermoProofCapturePanel(model: model, session: session)
            } else {
                FermoBreakGlassPanel(model: model, session: session)
            }
        } else {
            FermoProofCapturePanel(model: model, session: session)
        }
    }

    private func statusLabel(for session: FocusSession, now: Date) -> String {
        if session.isActive(at: now) {
            return session.rigor == .soft ? "Soft active" : "Protected"
        }
        return "Proof due"
    }

    private func statusReason(for session: FocusSession, now: Date) -> String {
        if session.isActive(at: now), session.rigor != .soft {
            return "Normal stop and rule weakening are locked until \(session.endsAt.formatted(date: .omitted, time: .shortened)). Break glass records a reason."
        }
        if session.isActive(at: now) {
            return "Soft mode can stop early, but Fermo still asks for a local not-done reason or proof."
        }
        return "The timer has elapsed. Record proof to close the contract and clear active protection."
    }

    private func statusTone(for session: FocusSession, now: Date) -> FermoStatusBadge.Tone {
        if !session.isActive(at: now) { return .warning }
        return session.rigor == .soft ? .info : .ok
    }

    private func timeDisplay(for session: FocusSession, now: Date) -> String {
        if now < session.startsAt {
            return formatDuration(session.startsAt.timeIntervalSince(now))
        }
        if now < session.endsAt {
            return formatDuration(session.endsAt.timeIntervalSince(now))
        }
        return "00:00"
    }

    private func progress(for session: FocusSession, now: Date) -> Double {
        guard session.duration > 0 else { return 0 }
        if now <= session.startsAt { return 0 }
        if now >= session.endsAt { return 1 }
        return now.timeIntervalSince(session.startsAt) / session.duration
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        let total = max(0, Int(value.rounded(.up)))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct FermoSoftStopPanel: View {
    @ObservedObject var model: FermoViewModel
    @State private var reason = ""

    var body: some View {
        FermoPanel("Soft Stop", subtitle: "Soft mode permits normal early exit, with an honest local reason.", symbol: "hand.raised") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Reason for stopping early", text: $reason, axis: .vertical)
                    .lineLimit(2...4)
                Button {
                    Task { await model.stopSoftContract(reason: reason) }
                } label: {
                    Label("Stop Soft Contract", systemImage: "stop.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(FermoTheme.warning)
            }
        }
    }
}

struct FermoBreakGlassPanel: View {
    @ObservedObject var model: FermoViewModel
    let session: FocusSession
    @State private var showSheet = false

    var body: some View {
        FermoPanel("Break Glass", subtitle: "Early exit for Locked/Emergency records a reason in evidence.", symbol: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(session.rigor.displayName) mode has no normal stop path while the timer is active. Breaking glass ends the session early and writes the reason to the evidence ledger.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(role: .destructive) {
                    showSheet = true
                } label: {
                    Label("Break Glass…", systemImage: "exclamationmark.triangle")
                }
                .buttonStyle(.borderedProminent)
                .tint(FermoTheme.danger)
            }
        }
        .sheet(isPresented: $showSheet) {
            BreakGlassSheet(model: model, session: session, isPresented: $showSheet)
        }
    }
}

/// Deliberate-friction modal: a session summary, a reason with a character minimum, and a
/// 2-second hold-to-confirm so breaking glass is never a single careless click.
private struct BreakGlassSheet: View {
    @ObservedObject var model: FermoViewModel
    let session: FocusSession
    @Binding var isPresented: Bool

    @State private var reason = ""
    @State private var isHolding = false
    private let minimumReasonLength = 23

    private var trimmedCount: Int {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).count
    }
    private var canConfirm: Bool { trimmedCount >= minimumReasonLength }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(FermoTheme.danger)
                Text("End \(session.rigor.displayName.lowercased()) session early")
                    .font(.headline)
                Spacer(minLength: 0)
            }

            TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow("Session", session.contract?.taskTitle ?? session.title)
                    summaryRow("Time used", "\(elapsed(now: timeline.date)) of \(total)")
                    summaryRow("Outcome", "broke-glass")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(FermoTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Why are you ending early?")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: $reason)
                    .font(.callout)
                    .frame(minHeight: 84)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(FermoTheme.panelRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(FermoTheme.line))
                Text("\(minimumReasonLength) characters minimum · \(trimmedCount) written")
                    .font(.caption2)
                    .foregroundStyle(canConfirm ? FermoTheme.accent : .secondary)
            }

            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.bordered)
                Spacer()
                holdToConfirmButton
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(FermoTheme.background)
    }

    private var holdToConfirmButton: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(canConfirm ? FermoTheme.danger.opacity(isHolding ? 0.45 : 0.85) : FermoTheme.danger.opacity(0.25))
            Label(isHolding ? "Hold…" : "Hold to confirm (2s)", systemImage: "exclamationmark.triangle")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .fixedSize()
        .opacity(canConfirm ? 1 : 0.6)
        .onLongPressGesture(minimumDuration: 2.0, pressing: { pressing in
            isHolding = canConfirm && pressing
        }, perform: {
            confirm()
        })
        .help(canConfirm ? "Hold for 2 seconds to break glass." : "Write at least \(minimumReasonLength) characters first.")
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.monospaced())
        }
    }

    private var total: String { formatClock(session.duration) }

    private func elapsed(now: Date) -> String {
        formatClock(max(0, min(session.duration, now.timeIntervalSince(session.startsAt))))
    }

    private func formatClock(_ value: TimeInterval) -> String {
        let total = max(0, Int(value.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    private func confirm() {
        guard canConfirm else { return }
        Task {
            await model.recordEvidence(
                EvidenceDraft(
                    outcome: .breakGlass,
                    note: "Ended early from the active session screen.",
                    breakGlassReason: reason
                )
            )
            isPresented = false
        }
    }
}
