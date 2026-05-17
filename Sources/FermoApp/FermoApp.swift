import FermoCore
import FermoSystem
import SwiftUI

@main
struct FermoApp: App {
    @StateObject private var model = FermoViewModel()

    var body: some Scene {
        MenuBarExtra("Fermo", systemImage: "lock.shield") {
            FermoMenuView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Fermo", id: "main") {
            FermoDashboardView(model: model)
        }
    }
}

@MainActor
final class FermoViewModel: ObservableObject {
    @Published var policy: FermoPolicy
    @Published var websiteBlockingStatus: WebsiteBlockingStatus = .needsPermission
    @Published var helperStatus: HelperRegistrationStatus = .notRegistered

    init() {
        self.policy = (try? FermoSampleData.policy()) ?? FermoPolicy()
    }

    var activeSession: FocusSession? {
        policy.activeSessions(at: Date()).first
    }

    var protectedDomains: [String] {
        policy.activeBlocklists(at: Date()).flatMap { blocklist in
            blocklist.domainRules.map(\.normalizedPattern)
        }
    }

    var protectedApps: [String] {
        Array(policy.blockedAppBundleIdentifiers(at: Date())).sorted()
    }
}

struct FermoMenuView: View {
    @ObservedObject var model: FermoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    Text(session.title)
                        .font(.subheadline.weight(.semibold))
                    Text("Ends \(session.endsAt.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                    if session.lockedMode {
                        Label("Locked Mode", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Divider()

            Label("\(model.protectedDomains.count) domains protected", systemImage: "network.badge.shield.half.filled")
            Label("\(model.protectedApps.count) apps protected", systemImage: "app.badge.checkmark")
            Label("Website filter: \(model.websiteBlockingStatus.rawValue)", systemImage: "globe")
            Label("Helper: \(model.helperStatus.rawValue)", systemImage: "gearshape.2")
        }
        .padding(16)
        .frame(width: 320)
    }
}

struct FermoDashboardView: View {
    @ObservedObject var model: FermoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "lock.shield")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                VStack(alignment: .leading) {
                    Text("Fermo")
                        .font(.largeTitle.weight(.semibold))
                    Text("macOS focus blocker scaffold")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            GroupBox("Current Gate") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Core model and UI shell are ready for dogfooding.")
                    Text("Network Extension, app interruption, and helper persistence still need signed-build technical validation.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Protected Domains") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.protectedDomains, id: \.self) { domain in
                        Label(domain, systemImage: "globe")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Protected Apps") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.protectedApps, id: \.self) { app in
                        Label(app, systemImage: "app")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 460)
    }
}
