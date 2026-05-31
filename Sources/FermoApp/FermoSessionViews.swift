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

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            FermoScreen(
                title: "Active Session",
                subtitle: "Timer, enforcement state, rules, proof, and break-glass in one place."
            ) {
                if let session = model.currentContractSession {
                    activeContent(session: session, now: timeline.date)
                } else {
                    FermoPanel("No Active Contract", symbol: "timer") {
                        Text("Start a contract to see its timer, rule boundary, system health, and proof controls here.")
                            .foregroundStyle(.secondary)
                    }
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
    @State private var reason = ""

    var body: some View {
        FermoPanel("Break Glass", subtitle: "Early exit for Locked/Emergency records a reason in evidence.", symbol: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(session.rigor.displayName) mode has no normal stop path while the timer is active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Break-glass reason", text: $reason, axis: .vertical)
                    .lineLimit(2...4)
                Button {
                    Task {
                        await model.recordEvidence(
                            EvidenceDraft(
                                outcome: .breakGlass,
                                note: "Ended early from the active session screen.",
                                breakGlassReason: reason
                            )
                        )
                    }
                } label: {
                    Label("Break Glass and Record", systemImage: "exclamationmark.triangle")
                }
                .buttonStyle(.borderedProminent)
                .tint(FermoTheme.danger)
            }
        }
    }
}
