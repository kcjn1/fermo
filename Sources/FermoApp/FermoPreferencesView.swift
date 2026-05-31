import FermoCore
import SwiftUI

struct FermoPreferencesView: View {
    @ObservedObject var model: FermoViewModel
    @State private var defaultPresetID = ""
    @State private var defaultRigor = ContractRigor.locked
    @State private var defaultDurationMinutes = 90.0

    var body: some View {
        FermoScreen(
            title: "Preferences",
            subtitle: "Defaults, helper registration, evidence storage, and diagnostics."
        ) {
            FermoPanel("Contract Defaults", symbol: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Preset", selection: $defaultPresetID) {
                        ForEach(model.presets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(model.presets.isEmpty)

                    Picker("Rigor", selection: $defaultRigor) {
                        ForEach(ContractRigor.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading) {
                        Text("Default duration: \(Int(defaultDurationMinutes)) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $defaultDurationMinutes, in: 25...180, step: 5)
                    }

                    Button {
                        model.saveContractDefaults(
                            presetID: defaultPresetID.isEmpty ? nil : defaultPresetID,
                            rigor: defaultRigor,
                            durationMinutes: Int(defaultDurationMinutes)
                        )
                    } label: {
                        Label("Save Defaults", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FermoTheme.accent)
                }
            }

            FermoPanel("Launch & Helper", symbol: "switch.2") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.onboardingChecklist.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 0) {
                        ForEach(Array(model.onboardingChecklist.items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider()
                            }
                            ProtectionOnboardingRow(item: item)
                        }
                    }

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

                    Divider()

                    FermoHealthRow(title: "Helper", detail: "Current status: \(model.helperStatus.displayName).", symbol: "externaldrive", tone: model.helperStatus.tone)
                    HStack {
                        Button {
                            Task { await model.startHelperSpike() }
                        } label: {
                            Label("Run Helper Diagnostic", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FermoTheme.accent)
                        .disabled(model.isUpdatingWebsiteFilter)

                        Button {
                            Task { await model.stopHelperSpike() }
                        } label: {
                            Label("Unregister Helper", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.openLoginItemsSettings()
                        } label: {
                            Label("Open Login Items", systemImage: "switch.2")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            FermoPanel("Privacy", symbol: "hand.raised") {
                Text("Fermo stores rooms, sessions, and evidence locally. No cloud sync and no AI calls in v1.")
                    .foregroundStyle(.secondary)
            }

            FermoPanel("Evidence Export", symbol: "folder") {
                VStack(alignment: .leading, spacing: 12) {
                    FermoHealthRow(
                        title: "Export Folder",
                        detail: model.evidenceExportDirectoryDescription,
                        symbol: "folder",
                        tone: .ok
                    )
                    FermoHealthRow(
                        title: "Folder Status",
                        detail: model.evidenceExportDestinationDiagnostic.message,
                        symbol: "checkmark.seal",
                        tone: model.evidenceExportDestinationDiagnostic.state == .ready || model.evidenceExportDestinationDiagnostic.state == .willCreate ? .ok : .warning
                    )
                    HStack {
                        Button {
                            model.chooseEvidenceExportDirectory()
                        } label: {
                            Label("Choose Folder", systemImage: "folder.badge.gearshape")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.exportEvidenceLedger()
                        } label: {
                            Label("Export Ledger", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FermoTheme.accent)
                        .disabled(model.policy.evidenceLog.isEmpty)
                    }
                }
            }

            FermoPanel("Diagnostics", symbol: "stethoscope") {
                VStack(alignment: .leading, spacing: 12) {
                    FermoHealthRow(
                        title: "Runtime Snapshot",
                        detail: "\(model.policy.sessions.count) sessions, \(model.schedules.count) schedules, \(model.policy.evidenceLog.count) evidence entries.",
                        symbol: "doc.text.magnifyingglass",
                        tone: .info
                    )
                    Button {
                        model.copyDiagnosticsReport()
                    } label: {
                        Label("Copy Diagnostics", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onAppear(perform: loadDefaults)
    }

    private func loadDefaults() {
        defaultPresetID = model.presets.contains { $0.id == model.preferences.defaultPresetID }
            ? model.preferences.defaultPresetID ?? ""
            : model.presets.first?.id ?? ""
        defaultRigor = model.preferences.defaultRigor
        defaultDurationMinutes = Double(model.preferences.defaultDurationMinutes)
    }
}
