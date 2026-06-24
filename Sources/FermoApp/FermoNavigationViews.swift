import FermoCore
import SwiftUI

struct FermoMenuView: View {
    @ObservedObject var model: FermoViewModel
    @State private var showDiagnostics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            switch model.menuBarState {
            case .idle: idleContent
            case .protected: protectedContent
            case .needsApproval: approvalContent
            case .degraded: degradedContent
            }

            Divider()

            Button {
                FermoMainWindowPresenter.shared.show()
            } label: {
                Label("Open Fermo", systemImage: "macwindow")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)

            diagnosticsDisclosure

            if let systemMessage = model.systemMessage {
                Text(systemMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 340)
        .task {
            await model.refreshWebsiteBlockingStatus()
            model.refreshHelperStatus()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: headerSymbol)
                .font(.title2)
                .foregroundStyle(headerTone.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(headerLabel)
                    .font(.headline)
                Text(headerSub)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var headerLabel: String {
        switch model.menuBarState {
        case .idle: "Ready"
        case .protected: model.activeSession != nil ? "Protected" : "Proof due"
        case .needsApproval: "Needs approval"
        case .degraded: "Degraded"
        }
    }

    private var headerSub: String {
        switch model.menuBarState {
        case .idle: "No active session. System protection is healthy."
        case .protected:
            if let session = model.activeSession {
                "\(session.rigor.displayName) session. Stop behavior depends on rigor."
            } else {
                "Timer elapsed. Record proof to close the contract."
            }
        case .needsApproval: "macOS needs to approve a protection before it can enforce."
        case .degraded: "Session is running, but one protection is partial."
        }
    }

    private var headerTone: FermoStatusBadge.Tone {
        switch model.menuBarState {
        case .idle: .ok
        case .protected: model.activeSession != nil ? .ok : .warning
        case .needsApproval: .info
        case .degraded: .warning
        }
    }

    private var headerSymbol: String {
        switch model.menuBarState {
        case .idle: "lock.shield"
        case .protected: model.activeSession != nil ? "lock.shield.fill" : "checkmark.seal"
        case .needsApproval: "exclamationmark.shield"
        case .degraded: "exclamationmark.triangle"
        }
    }

    // MARK: Idle — Quick start

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            menuSectionHeader("Quick start", actionTitle: "New contract…") {
                FermoMainWindowPresenter.shared.show()
            }
            ForEach(Array(model.presets.prefix(4).enumerated()), id: \.element.id) { index, preset in
                presetRow(preset, index: index)
            }

            if let entry = model.lastEvidenceEntry {
                Divider().padding(.vertical, 2)
                menuSectionHeader("Last session · \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                HStack(spacing: 8) {
                    FermoStatusBadge(label: entry.outcome.displayName, tone: entry.outcome.tone)
                    Text(entry.taskTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func presetRow(_ preset: FocusPreset, index: Int) -> some View {
        Button {
            Task { await model.startPreset(preset) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: preset.mode.symbol)
                    .foregroundStyle(FermoTheme.accent)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name).font(.callout.weight(.medium))
                    Text(model.presetSummary(preset))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if index < 4 {
                    Text("⌘\(index + 1)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
        .disabled(model.isUpdatingWebsiteFilter)
    }

    // MARK: Protected

    @ViewBuilder
    private var protectedContent: some View {
        if let session = model.currentContractSession {
            TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.contract?.taskTitle ?? session.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(menuCountdown(for: session, now: timeline.date))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    ProgressView(value: menuProgress(for: session, now: timeline.date))
                        .tint(session.isActive(at: timeline.date) ? FermoTheme.accent : FermoTheme.warning)
                    HStack(spacing: 6) {
                        FermoStatusBadge(label: "\(model.protectedDomains.count) domains", tone: .info)
                        FermoStatusBadge(label: "\(model.protectedApps.count) apps", tone: .info)
                        if session.rigor != .soft {
                            FermoStatusBadge(label: "\(session.rigor.displayName) locked", tone: .ok)
                        }
                    }
                    Button {
                        FermoMainWindowPresenter.shared.show()
                    } label: {
                        Label(session.isActive(at: timeline.date) ? "Open session controls" : "Record proof", systemImage: "timer")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FermoTheme.accent)
                }
            }
        }
    }

    // MARK: Needs approval

    private var approvalContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            FermoStatusStrip(
                label: "Approval needed",
                reason: model.onboardingChecklist.summary,
                tone: .info,
                actionTitle: "Open System Settings",
                action: { model.openSystemSettings() }
            )
            let pending = model.onboardingChecklist.items.filter { $0.state != .ready }
            if !pending.isEmpty {
                menuSectionHeader("Affected checks")
                ForEach(pending) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(FermoTheme.warning)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).font(.caption.weight(.medium))
                            Text(item.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            Text("Quick start would run unprotected until approval finishes.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Degraded

    private var degradedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            FermoStatusStrip(
                label: "Protection partial",
                reason: degradedReason,
                tone: .warning
            )
            HStack {
                Button {
                    Task {
                        await model.refreshWebsiteBlockingStatus()
                        model.refreshHelperStatus()
                    }
                } label: {
                    Label("Recheck", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                Button {
                    FermoMainWindowPresenter.shared.show()
                } label: {
                    Label("Open session", systemImage: "timer")
                }
                .buttonStyle(.borderedProminent)
                .tint(FermoTheme.accent)
            }
        }
    }

    private var degradedReason: String {
        if model.latestAppInterruptionReport?.requiresStrongerHandling == true {
            return "An app resisted graceful termination. Fermo does not overclaim enforcement here."
        }
        return "Website filter is \(model.websiteBlockingStatus.displayName). Reapply protection or open the session."
    }

    // MARK: Diagnostics (off the daily surface)

    private var diagnosticsDisclosure: some View {
        DisclosureGroup(isExpanded: $showDiagnostics) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button { Task { await model.startWebsiteSpike() } } label: { Label("Website", systemImage: "play.fill") }
                        .disabled(model.isUpdatingWebsiteFilter)
                    Button { Task { await model.stopWebsiteSpike() } } label: { Label("Stop", systemImage: "stop.fill") }
                        .disabled(model.isUpdatingWebsiteFilter)
                }
                HStack {
                    Button { Task { await model.startAppSpike() } } label: { Label("App", systemImage: "play.circle") }
                    Button { Task { await model.stopAppSpike() } } label: { Label("Stop", systemImage: "stop.circle") }
                        .disabled(!model.isAppInterruptionMonitorActive)
                }
                HStack {
                    Button { Task { await model.startHelperSpike() } } label: { Label("Helper", systemImage: "gearshape.2") }
                        .disabled(model.isUpdatingWebsiteFilter)
                    Button { Task { await model.stopHelperSpike() } } label: { Label("Unregister", systemImage: "xmark.circle") }
                }
                Button { Task { await model.requestAppGuardApproval() } } label: { Label("Approve App Guard", systemImage: "lock.shield") }
                    .disabled(model.isRequestingAppGuardApproval)
                Button { model.openLoginItemsSettings() } label: { Label("Open Login Items", systemImage: "switch.2") }
            }
            .font(.caption)
            .padding(.top, 6)
        } label: {
            Text("Developer diagnostics")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func menuSectionHeader(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(FermoTheme.accent)
            }
        }
    }

    private func menuCountdown(for session: FocusSession, now: Date) -> String {
        let remaining = max(0, session.endsAt.timeIntervalSince(now))
        let total = Int(remaining.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    private func menuProgress(for session: FocusSession, now: Date) -> Double {
        guard session.duration > 0 else { return 0 }
        if now <= session.startsAt { return 0 }
        if now >= session.endsAt { return 1 }
        return now.timeIntervalSince(session.startsAt) / session.duration
    }
}

struct FermoDashboardView: View {
    @ObservedObject var model: FermoViewModel
    @State private var selection: FermoArea? = .today

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Session") {
                    ForEach(FermoArea.session) { area in
                        FermoSidebarLabel(area: area)
                    }
                }

                Section("Library") {
                    ForEach(FermoArea.library) { area in
                        FermoSidebarLabel(area: area)
                    }
                }

                Section("System") {
                    ForEach(FermoArea.system) { area in
                        FermoSidebarLabel(area: area)
                    }
                }
            }
            .navigationTitle("Fermo")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            FermoDetailView(selection: $selection, model: model)
        }
        .tint(FermoTheme.accent)
        .frame(minWidth: 980, minHeight: 680)
        .task {
            await model.refreshWebsiteBlockingStatus()
            model.refreshHelperStatus()
        }
    }
}

private enum FermoArea: String, CaseIterable, Identifiable, Hashable {
    case today
    case active
    case start
    case rooms
    case evidence
    case health
    case preferences

    var id: Self { self }

    static let session: [Self] = [.today, .active, .start]
    static let library: [Self] = [.rooms, .evidence]
    static let system: [Self] = [.health, .preferences]

    var title: String {
        switch self {
        case .today: "Today"
        case .active: "Active Session"
        case .start: "Start Contract"
        case .rooms: "Rooms"
        case .evidence: "Evidence"
        case .health: "System Health"
        case .preferences: "Preferences"
        }
    }

    var symbol: String {
        switch self {
        case .today: "house"
        case .active: "timer"
        case .start: "play.fill"
        case .rooms: "square.grid.2x2"
        case .evidence: "list.bullet.clipboard"
        case .health: "lock.shield"
        case .preferences: "gearshape"
        }
    }
}

private struct FermoSidebarLabel: View {
    let area: FermoArea

    var body: some View {
        Label(area.title, systemImage: area.symbol)
            .tag(area)
    }
}

private struct FermoDetailView: View {
    @Binding var selection: FermoArea?
    @ObservedObject var model: FermoViewModel

    var body: some View {
        Group {
            switch selection ?? .today {
            case .today:
                FermoTodayView(model: model) {
                    selection = .start
                } onOpenActive: {
                    selection = .active
                }
            case .active:
                FermoActiveSessionView(model: model) {
                    selection = .start
                }
            case .start:
                FermoStartContractView(model: model)
            case .rooms:
                FermoRoomsView(model: model) {
                    selection = .start
                }
            case .evidence:
                FermoEvidenceView(model: model) {
                    selection = .start
                }
            case .health:
                FermoSystemHealthView(model: model)
            case .preferences:
                FermoPreferencesView(model: model)
            }
        }
        .background(FermoTheme.background)
    }
}
