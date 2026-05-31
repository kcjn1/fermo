import SwiftUI

struct FermoMenuView: View {
    @ObservedObject var model: FermoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                FermoMainWindowPresenter.shared.show()
            } label: {
                Label("Open Fermo", systemImage: "macwindow")
            }

            Divider()

            HStack {
                Image(systemName: "lock.shield")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fermo")
                        .font(.headline)
                    Text(model.activeSession == nil ? "No active session" : "Focus session active")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let session = model.activeSession {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.contract?.taskTitle ?? session.title)
                        .font(.subheadline.weight(.semibold))
                    if let outcome = session.contract?.intendedOutcome {
                        Text(outcome)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text("Ends \(session.endsAt.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                    Label("\(session.rigor.rawValue.capitalized) contract", systemImage: session.rigor == .soft ? "hand.raised" : "lock.fill")
                        .font(.caption)
                        .foregroundStyle(session.rigor == .soft ? Color.secondary : Color.orange)
                    if session.contract?.mode == .focusRoom {
                        Label("Focus Room", systemImage: "door.left.hand.closed")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Divider()

            Label("\(model.protectedDomains.count) domains protected", systemImage: "network.badge.shield.half.filled")
            Label("\(model.protectedApps.count) apps protected", systemImage: "app.badge.checkmark")
            Label("Website filter: \(model.websiteBlockingStatus.rawValue)", systemImage: "globe")
            Label("App Guard: \(model.appGuardApprovalStatus.displayName)", systemImage: "lock.shield")
            Label("App interruption: \(model.appInterruptionStatusText)", systemImage: "app.dashed")
            Label("Helper: \(model.helperStatus.rawValue)", systemImage: "gearshape.2")

            Divider()

            HStack {
                Button {
                    Task { await model.startWebsiteSpike() }
                } label: {
                    Label("Run Website Diagnostic", systemImage: "play.fill")
                }
                .disabled(model.isUpdatingWebsiteFilter)

                Button {
                    Task { await model.stopWebsiteSpike() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(model.isUpdatingWebsiteFilter)
            }

            HStack {
                Button {
                    Task { await model.startAppSpike() }
                } label: {
                    Label("Run App Diagnostic", systemImage: "play.circle")
                }

                Button {
                    Task { await model.stopAppSpike() }
                } label: {
                    Label("Stop Apps", systemImage: "stop.circle")
                }
                .disabled(!model.isAppInterruptionMonitorActive)
            }

            HStack {
                Button {
                    Task { await model.startHelperSpike() }
                } label: {
                    Label("Run Helper Diagnostic", systemImage: "gearshape.2")
                }
                .disabled(model.isUpdatingWebsiteFilter)

                Button {
                    Task { await model.stopHelperSpike() }
                } label: {
                    Label("Unregister", systemImage: "xmark.circle")
                }
            }

            Button {
                Task { await model.requestAppGuardApproval() }
            } label: {
                Label("Approve App Guard", systemImage: "lock.shield")
            }
            .disabled(model.isRequestingAppGuardApproval)

            Button {
                model.openLoginItemsSettings()
            } label: {
                Label("Open Login Items", systemImage: "switch.2")
            }

            if let systemMessage = model.systemMessage {
                Text(systemMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 320)
        .task {
            await model.refreshWebsiteBlockingStatus()
            model.refreshHelperStatus()
        }
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
                FermoActiveSessionView(model: model)
            case .start:
                FermoStartContractView(model: model)
            case .rooms:
                FermoRoomsView(model: model)
            case .evidence:
                FermoEvidenceView(model: model)
            case .health:
                FermoSystemHealthView(model: model)
            case .preferences:
                FermoPreferencesView(model: model)
            }
        }
        .background(FermoTheme.background)
    }
}
