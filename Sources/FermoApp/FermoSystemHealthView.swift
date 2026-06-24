import FermoSystem
import SwiftUI

struct FermoSystemHealthView: View {
    @ObservedObject var model: FermoViewModel

    var body: some View {
        FermoScreen(
            title: "System Health",
            subtitle: "What macOS lets Fermo enforce, in plain language."
        ) {
            FermoStatusStrip(
                label: "Pre-beta validation",
                reason: "Local dev checks are in place. Toolary beta still needs Endpoint Security approval and the signed runtime matrix.",
                tone: .warning
            )

            FermoPanel("Approvals & Extensions", symbol: "lock.shield") {
                VStack(spacing: 0) {
                    ForEach(Array(model.onboardingChecklist.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider()
                        }
                        ProtectionOnboardingRow(item: item)
                    }
                    Divider()
                    FermoHealthRow(title: "System Extensions", detail: "Network and App Guard extensions build locally. Final beta must be approved from signed /Applications/Fermo.app.", symbol: "lock.shield", tone: .warning)
                    Divider()
                    FermoHealthRow(title: "Signing / Developer Team", detail: "Development signing is configured. Developer ID signing and notarization remain required for beta.", symbol: "checkmark.seal", tone: .warning)
                    Divider()
                    FermoHealthRow(title: "Notarization", detail: "Not cut yet. Required before Toolary beta distribution.", symbol: "doc.text", tone: .muted)
                }
            }

            FermoPanel("App Guard Approval", symbol: "lock.shield") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Endpoint Security approval is required before Fermo can deny app launch/relaunch during protected sessions.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button {
                            Task { await model.requestAppGuardApproval() }
                        } label: {
                            Label("Request App Guard Approval", systemImage: "lock.shield")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FermoTheme.accent)
                        .disabled(model.isRequestingAppGuardApproval)

                        Button {
                            model.openSystemSettings()
                        } label: {
                            Label("Open System Settings", systemImage: "gearshape")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            FermoPanel("Blocking & Interruption", symbol: "shield") {
                VStack(spacing: 0) {
                    FermoHealthRow(title: "Website Blocking", detail: "Uses the content filter when approved. Safari, Chrome, Firefox, and private/incognito still need final matrix validation.", symbol: "globe", tone: model.websiteBlockingStatus.tone)
                    Divider()
                    FermoHealthRow(
                        title: "Content Filter Snapshot",
                        detail: model.contentFilterRuntimeDiagnostic?.summary ?? "Content filter snapshot path is unavailable because the app group container was not resolved.",
                        symbol: "doc.text.magnifyingglass",
                        tone: model.contentFilterRuntimeDiagnostic?.state.fermoTone ?? .warning
                    )
                    Divider()
                    FermoHealthRow(title: "App Interruption", detail: model.appInterruptionStatusText, symbol: "app.dashed", tone: model.isAppInterruptionMonitorActive ? .ok : .muted)
                    Divider()
                    FermoHealthRow(title: "Helper / Login Item", detail: "Status: \(model.helperStatus.displayName). Reboot/login restore still needs signed runtime validation.", symbol: "externaldrive", tone: model.helperStatus.tone)
                    Divider()
                    FermoHealthRow(title: "App Group Shared State", detail: "App, helper, and filter share snapshots through the configured app group.", symbol: "tray.full", tone: .ok)
                }
            }

            FermoPanel("Manual Checks Still Blocking Beta", symbol: "questionmark.circle") {
                VStack(spacing: 0) {
                    ManualCheckRow("Sleep / wake restore")
                    Divider()
                    ManualCheckRow("Reboot / login restore")
                    Divider()
                    ManualCheckRow("Wi-Fi change")
                    Divider()
                    ManualCheckRow("Firefox validation")
                    Divider()
                    ManualCheckRow("Safari private and Chrome incognito")
                }
            }

            FermoPanel("Diagnostics", symbol: "stethoscope") {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal) {
                        Text(model.diagnosticsReport)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Button {
                        model.copyDiagnosticsReport()
                    } label: {
                        Label("Copy Diagnostics", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FermoTheme.accent)
                }
            }
        }
    }
}

struct FermoHealthRow: View {
    let title: String
    let detail: String
    let symbol: String
    let tone: FermoStatusBadge.Tone

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tone.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            FermoStatusBadge(label: tone.label, tone: tone)
        }
        .padding(.vertical, 10)
    }
}

struct ProtectionOnboardingRow: View {
    let item: ProtectionOnboardingItem

    var body: some View {
        FermoHealthRow(
            title: item.title,
            detail: item.detail,
            symbol: item.state.symbol,
            tone: item.state.fermoTone
        )
    }
}

struct ManualCheckRow: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        FermoHealthRow(
            title: title,
            detail: "Unverified on the final signed/notarized candidate. Keep visible before any beta claim.",
            symbol: "questionmark.circle",
            tone: .warning
        )
    }
}

extension FermoStatusBadge.Tone {
    var label: String {
        switch self {
        case .ok: "Ready"
        case .info: "Needs approval"
        case .warning: "Unverified"
        case .danger: "Error"
        case .muted: "Not installed"
        }
    }
}

extension ProtectionOnboardingState {
    var fermoTone: FermoStatusBadge.Tone {
        switch self {
        case .ready:
            return .ok
        case .actionNeeded:
            return .warning
        case .unavailable:
            return .muted
        }
    }

    var symbol: String {
        switch self {
        case .ready:
            return "checkmark.seal"
        case .actionNeeded:
            return "exclamationmark.triangle"
        case .unavailable:
            return "slash.circle"
        }
    }
}

extension WebsiteBlockingStatus {
    var displayName: String {
        switch self {
        case .unavailable: "Unavailable"
        case .needsPermission: "Setup needed"
        case .ready: "Ready"
        case .active: "Active"
        }
    }

    var tone: FermoStatusBadge.Tone {
        switch self {
        case .active, .ready: .ok
        case .needsPermission: .warning
        case .unavailable: .muted
        }
    }
}

extension HelperRegistrationStatus {
    var displayName: String {
        switch self {
        case .unavailable: "Unavailable"
        case .notRegistered: "Not registered"
        case .requiresApproval: "Needs approval"
        case .enabled: "Enabled"
        case .notFound: "Not found"
        }
    }

    var tone: FermoStatusBadge.Tone {
        switch self {
        case .enabled: .ok
        case .requiresApproval: .warning
        case .notRegistered, .notFound, .unavailable: .muted
        }
    }
}

extension SystemExtensionApprovalStatus {
    var fermoTone: FermoStatusBadge.Tone {
        switch tone {
        case .ok:
            return .ok
        case .warning:
            return .warning
        case .muted:
            return .muted
        }
    }
}

extension ContentFilterRuntimeDiagnosticState {
    var fermoTone: FermoStatusBadge.Tone {
        switch self {
        case .ready:
            return .ok
        case .noActiveRules, .expiredSnapshot:
            return .muted
        case .missingSnapshot, .unreadableSnapshot:
            return .warning
        }
    }
}
