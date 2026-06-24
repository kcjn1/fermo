import FermoCore
import SwiftUI

struct FermoStartContractView: View {
    @ObservedObject var model: FermoViewModel
    @State private var task = "Draft reliability memo"
    @State private var outcome = "Publish a complete first draft with next steps."
    @State private var selectedPresetID = ""
    @State private var mode = FocusMode.focusRoom
    @State private var rigor = ContractRigor.locked
    @State private var duration = 90.0
    @State private var requiredProof = RequiredProof.markdown
    @State private var ruleState = ContractRuleEditorState()
    @State private var timing = ContractStartTiming.now
    @State private var startsAt = Date().addingTimeInterval(3_600)

    var body: some View {
        FermoScreen(
            title: "Start Contract",
            subtitle: "A fast native flow for task, intended outcome, room, rigor, and proof."
        ) {
            FermoPanel("Contract", subtitle: "Creates a real active FermoCore policy and asks macOS to enforce it.", symbol: "doc.text") {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Task", text: $task)
                    TextField("Intended outcome", text: $outcome, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Preset", selection: $selectedPresetID) {
                        ForEach(model.presets) { value in
                            Text(value.name).tag(value.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Mode", selection: $mode) {
                        Text("Focus Room").tag(FocusMode.focusRoom)
                        Text("Blocklist").tag(FocusMode.blocklist)
                    }
                    .pickerStyle(.segmented)
                    Picker("Rigor", selection: $rigor) {
                        ForEach(ContractRigor.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Proof requirement", selection: $requiredProof) {
                        ForEach(RequiredProof.allCases, id: \.self) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(requiredProof.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Start", selection: $timing) {
                        ForEach(ContractStartTiming.allCases, id: \.self) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    if timing == .later {
                        DatePicker("Start time", selection: $startsAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    }
                    VStack(alignment: .leading) {
                        Text("Duration: \(Int(duration)) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $duration, in: 25...180, step: 5)
                    }
                    Text("Locked means no normal stop path during the session. Fermo does not pretend to be tamper-proof.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            startContract()
                        } label: {
                            Label(timing == .now ? "Start Contract" : "Schedule Contract", systemImage: timing == .now ? "play.fill" : "calendar.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FermoTheme.accent)
                        .disabled(model.isUpdatingWebsiteFilter)

                        Button {
                            model.savePreset(name: task, mode: mode, rigor: rigor, ruleDraft: ruleState.draft)
                        } label: {
                            Label("Save as preset", systemImage: "bookmark")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            model.saveDraft(currentSavedDraft())
                        } label: {
                            Label("Save draft", systemImage: "tray.and.arrow.down")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            Task { await model.clearDiagnostics() }
                        } label: {
                            Label("Clear Diagnostics", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if selectedPreset != nil {
                FermoPanel("Room Rules", subtitle: mode.displayName, symbol: "square.grid.2x2") {
                    ContractRuleEditorForm(state: $ruleState, mode: mode)
                }

                FermoPanel("Rule Preview", subtitle: "Applied when the contract starts.", symbol: "checklist") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        RuleList(
                            title: "Blocked websites",
                            symbol: "globe",
                            items: ruleState.blockedDomainLines
                        )
                        RuleList(
                            title: "Allowed websites",
                            symbol: "checkmark.circle",
                            items: ruleState.allowedDomainLines
                        )
                        RuleList(
                            title: "Blocked apps",
                            symbol: "app.dashed",
                            items: ruleState.blockedAppLines
                        )
                        RuleList(
                            title: "Allowed apps",
                            symbol: "checkmark.seal",
                            items: ruleState.allowedAppLines
                        )
                    }
                }
            }

            FermoSchedulePanel(model: model)
        }
        .onAppear(perform: applyInitialState)
        .onChange(of: selectedPresetID) {
            applySelectedPreset()
        }
    }

    private var selectedPreset: FocusPreset? {
        model.presets.first { $0.id == selectedPresetID } ?? model.presets.first
    }

    private func applyInitialState() {
        // A saved draft is the operator's intended next contract; resume it without touching
        // selectedPresetID so the preset onChange does not clobber the restored rules.
        if let draft = model.savedDraft {
            task = draft.taskTitle
            outcome = draft.intendedOutcome
            mode = draft.mode
            rigor = draft.rigor
            requiredProof = draft.requiredProof
            duration = Double(draft.durationMinutes)
            ruleState = ContractRuleEditorState(savedDraft: draft)
            return
        }
        applyPreferredDefaults()
    }

    private func currentSavedDraft() -> SavedContractDraft {
        SavedContractDraft(
            taskTitle: task,
            intendedOutcome: outcome,
            mode: mode,
            rigor: rigor,
            requiredProof: requiredProof,
            durationMinutes: Int(duration),
            blockedDomainPatterns: ruleState.blockedDomainLines,
            allowedDomainPatterns: ruleState.allowedDomainLines,
            blockedApps: ruleState.blockedAppLines.map { AppRule(bundleIdentifier: $0, displayName: $0) },
            allowedApps: ruleState.allowedAppLines.map { AppRule(bundleIdentifier: $0, displayName: $0) }
        )
    }

    private func applyPreferredDefaults() {
        let preferredPresetID = model.preferences.defaultPresetID
        selectedPresetID = model.presets.contains { $0.id == preferredPresetID }
            ? preferredPresetID ?? ""
            : model.presets.first?.id ?? ""
        rigor = model.preferences.defaultRigor
        duration = Double(model.preferences.defaultDurationMinutes)
        applySelectedPreset(shouldApplyRigor: false)
    }

    private func applySelectedPreset() {
        applySelectedPreset(shouldApplyRigor: true)
    }

    private func applySelectedPreset(shouldApplyRigor: Bool) {
        guard let selectedPreset else { return }
        mode = selectedPreset.mode
        if shouldApplyRigor {
            rigor = selectedPreset.suggestedRigor
        }
        ruleState = ContractRuleEditorState(preset: selectedPreset)
    }

    private func startContract() {
        let hadDraft = model.savedDraft != nil
        Task {
            switch timing {
            case .now:
                await model.startContract(
                    taskTitle: task,
                    intendedOutcome: outcome,
                    mode: mode,
                    rigor: rigor,
                    duration: duration * 60,
                    ruleDraft: ruleState.draft,
                    requiredProof: requiredProof
                )
            case .later:
                await model.scheduleContract(
                    taskTitle: task,
                    intendedOutcome: outcome,
                    mode: mode,
                    rigor: rigor,
                    duration: duration * 60,
                    startsAt: startsAt,
                    ruleDraft: ruleState.draft,
                    requiredProof: requiredProof
                )
            }
            // Starting consumes the saved "next contract" draft.
            if hadDraft { model.clearSavedDraft() }
        }
    }
}

enum ContractStartTiming: CaseIterable {
    case now
    case later

    var label: String {
        switch self {
        case .now: "Now"
        case .later: "Later"
        }
    }
}

struct ContractRuleEditorState: Equatable {
    var blockedDomainsText = ""
    var blockedAppsText = ""
    var allowedDomainsText = ""
    var allowedAppsText = ""

    init() {}

    init(preset: FocusPreset) {
        self.blockedDomainsText = preset.blockedDomains.map(\.rawPattern).joined(separator: "\n")
        self.blockedAppsText = preset.blockedApps.map(\.bundleIdentifier).joined(separator: "\n")
        self.allowedDomainsText = preset.allowedDomains.map(\.rawPattern).joined(separator: "\n")
        self.allowedAppsText = preset.allowedApps.map(\.bundleIdentifier).joined(separator: "\n")
    }

    init(savedDraft: SavedContractDraft) {
        self.blockedDomainsText = savedDraft.blockedDomainPatterns.joined(separator: "\n")
        self.blockedAppsText = savedDraft.blockedApps.map(\.bundleIdentifier).joined(separator: "\n")
        self.allowedDomainsText = savedDraft.allowedDomainPatterns.joined(separator: "\n")
        self.allowedAppsText = savedDraft.allowedApps.map(\.bundleIdentifier).joined(separator: "\n")
    }

    var draft: FocusContractRuleDraft {
        FocusContractRuleDraft(
            blockedDomainPatterns: blockedDomainLines,
            blockedAppRules: blockedAppLines.map { EditableAppRule(bundleIdentifier: $0) },
            allowedDomainPatterns: allowedDomainLines,
            allowedAppRules: allowedAppLines.map { EditableAppRule(bundleIdentifier: $0) }
        )
    }

    var blockedDomainLines: [String] {
        Self.lines(from: blockedDomainsText)
    }

    var blockedAppLines: [String] {
        Self.lines(from: blockedAppsText)
    }

    var allowedDomainLines: [String] {
        Self.lines(from: allowedDomainsText)
    }

    var allowedAppLines: [String] {
        Self.lines(from: allowedAppsText)
    }

    private static func lines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct ContractRuleEditorForm: View {
    @Binding var state: ContractRuleEditorState
    let mode: FocusMode

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ruleEditor(
                title: "Blocked websites",
                symbol: "globe",
                text: $state.blockedDomainsText,
                isPrimary: mode == .blocklist
            )
            ruleEditor(
                title: "Allowed websites",
                symbol: "checkmark.circle",
                text: $state.allowedDomainsText,
                isPrimary: mode == .focusRoom
            )
            ruleEditor(
                title: "Blocked apps",
                symbol: "app.dashed",
                text: $state.blockedAppsText,
                isPrimary: mode == .blocklist
            )
            ruleEditor(
                title: "Allowed apps",
                symbol: "checkmark.seal",
                text: $state.allowedAppsText,
                isPrimary: mode == .focusRoom
            )
        }
    }

    private func ruleEditor(
        title: String,
        symbol: String,
        text: Binding<String>,
        isPrimary: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.semibold))
                if isPrimary {
                    FermoStatusBadge(label: "Required", tone: .info)
                }
            }
            TextEditor(text: text)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .background(FermoTheme.panelRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct FermoSchedulePanel: View {
    @ObservedObject var model: FermoViewModel
    @State private var name = "Morning Focus"
    @State private var selectedWeekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var duration = 90.0
    @State private var selectedBlocklistID: UUID?
    @State private var scheduleMode = FocusMode.blocklist
    @State private var allowedDomainsText = ""
    @State private var allowedAppsText = ""
    @State private var lockedMode = true
    @State private var isEnabled = true
    @State private var editingScheduleID: UUID?

    var body: some View {
        FermoPanel("Schedules", subtitle: "\(model.schedules.count) saved", symbol: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Schedule name", text: $name)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                        ForEach(Weekday.allCases, id: \.self) { weekday in
                            Button {
                                toggle(weekday)
                            } label: {
                                Text(weekday.shortName)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedWeekdays.contains(weekday) ? FermoTheme.accent : .secondary)
                        }
                    }

                    Picker("Mode", selection: $scheduleMode) {
                        Text("Blocklist").tag(FocusMode.blocklist)
                        Text("Focus Room").tag(FocusMode.focusRoom)
                    }
                    .pickerStyle(.segmented)

                    if scheduleMode == .blocklist {
                        if model.policy.blocklists.isEmpty {
                            FermoStatusStrip(
                                label: "No rooms yet",
                                reason: "Create a room first, or switch this schedule to Focus Room mode.",
                                tone: .warning
                            )
                        } else {
                            Picker("Room", selection: selectedBlocklistBinding) {
                                ForEach(model.policy.blocklists) { blocklist in
                                    Text(blocklist.name).tag(blocklist.id)
                                }
                            }
                            .frame(maxWidth: 280)
                        }
                    } else {
                        scheduleRuleEditor(title: "Allowed websites", symbol: "checkmark.circle", text: $allowedDomainsText)
                        scheduleRuleEditor(title: "Allowed apps (bundle IDs)", symbol: "checkmark.seal", text: $allowedAppsText)
                    }

                    HStack {
                        Stepper("Start \(String(format: "%02d:%02d", startHour, startMinute))", value: $startHour, in: 0...23)
                        Stepper("Minute \(String(format: "%02d", startMinute))", value: $startMinute, in: 0...55, step: 5)
                    }

                    VStack(alignment: .leading) {
                        Text("Duration: \(Int(duration)) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $duration, in: 25...180, step: 5)
                    }

                    HStack {
                        Toggle("Locked schedule", isOn: $lockedMode)
                        Toggle("Enabled", isOn: $isEnabled)
                    }

                    HStack {
                        Button {
                            save()
                        } label: {
                            Label(editingScheduleID == nil ? "Save Schedule" : "Update Schedule", systemImage: editingScheduleID == nil ? "calendar.badge.plus" : "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FermoTheme.accent)
                        .disabled(!canSaveSchedule)

                        if editingScheduleID != nil {
                            Button {
                                resetEditor()
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if !model.schedules.isEmpty {
                    Divider()
                    VStack(spacing: 0) {
                        ForEach(model.schedules) { schedule in
                            ScheduleRow(
                                schedule: schedule,
                                blocklistName: blocklistName(for: schedule),
                                onEdit: { edit(schedule) },
                                onDelete: { model.deleteSchedule(id: schedule.id) }
                            )
                            if schedule.id != model.schedules.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            selectedBlocklistID = selectedBlocklistID ?? model.policy.blocklists.first?.id
        }
        .onChange(of: model.policy.blocklists.map(\.id)) {
            if selectedBlocklistID == nil || !model.policy.blocklists.contains(where: { $0.id == selectedBlocklistID }) {
                selectedBlocklistID = model.policy.blocklists.first?.id
            }
        }
    }

    private var selectedBlocklistBinding: Binding<UUID> {
        Binding(
            get: { selectedBlocklistID ?? model.policy.blocklists.first?.id ?? UUID() },
            set: { selectedBlocklistID = $0 }
        )
    }

    private func toggle(_ weekday: Weekday) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    private var allowedDomainLines: [String] { Self.lines(from: allowedDomainsText) }
    private var allowedAppLines: [String] { Self.lines(from: allowedAppsText) }

    private static func lines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSaveSchedule: Bool {
        guard !selectedWeekdays.isEmpty else { return false }
        switch scheduleMode {
        case .blocklist: return selectedBlocklistID != nil && !model.policy.blocklists.isEmpty
        case .focusRoom: return !allowedDomainLines.isEmpty || !allowedAppLines.isEmpty
        }
    }

    @ViewBuilder
    private func scheduleRuleEditor(title: String, symbol: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
            TextEditor(text: text)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(FermoTheme.panelRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(FermoTheme.line))
        }
    }

    private func save() {
        do {
            let draft: WeeklyScheduleEditorDraft
            switch scheduleMode {
            case .blocklist:
                guard let selectedBlocklistID else { return }
                draft = WeeklyScheduleEditorDraft(
                    id: editingScheduleID,
                    name: name,
                    weekdays: selectedWeekdays,
                    startHour: startHour,
                    startMinute: startMinute,
                    durationMinutes: Int(duration),
                    blocklistIDs: [selectedBlocklistID],
                    lockedMode: lockedMode,
                    isEnabled: isEnabled,
                    mode: .blocklist
                )
            case .focusRoom:
                let allowedDomains = try allowedDomainLines.map(DomainRule.init)
                let allowedApps = allowedAppLines.map { AppRule(bundleIdentifier: $0, displayName: $0) }
                draft = WeeklyScheduleEditorDraft(
                    id: editingScheduleID,
                    name: name,
                    weekdays: selectedWeekdays,
                    startHour: startHour,
                    startMinute: startMinute,
                    durationMinutes: Int(duration),
                    blocklistIDs: [],
                    lockedMode: lockedMode,
                    isEnabled: isEnabled,
                    mode: .focusRoom,
                    allowedDomains: allowedDomains,
                    allowedApps: allowedApps
                )
            }
            model.saveSchedule(try draft.schedule())
            resetEditor(keepingSelectedRoom: true)
        } catch {
            model.systemMessage = "Schedule could not be saved: \(String(describing: error))"
        }
    }

    private func edit(_ schedule: WeeklySchedule) {
        editingScheduleID = schedule.id
        name = schedule.name
        selectedWeekdays = schedule.weekdays
        startHour = schedule.startHour
        startMinute = schedule.startMinute
        duration = schedule.duration / 60
        selectedBlocklistID = schedule.blocklistIDs.first ?? model.policy.blocklists.first?.id
        scheduleMode = schedule.mode
        allowedDomainsText = schedule.allowedDomains.map(\.rawPattern).joined(separator: "\n")
        allowedAppsText = schedule.allowedApps.map(\.bundleIdentifier).joined(separator: "\n")
        lockedMode = schedule.lockedMode
        isEnabled = schedule.isEnabled
    }

    private func resetEditor(keepingSelectedRoom: Bool = false) {
        let currentRoom = selectedBlocklistID
        editingScheduleID = nil
        name = "Morning Focus"
        selectedWeekdays = [.monday, .tuesday, .wednesday, .thursday, .friday]
        startHour = 9
        startMinute = 0
        duration = 90
        selectedBlocklistID = keepingSelectedRoom ? currentRoom : model.policy.blocklists.first?.id
        scheduleMode = .blocklist
        allowedDomainsText = ""
        allowedAppsText = ""
        lockedMode = true
        isEnabled = true
    }

    private func blocklistName(for schedule: WeeklySchedule) -> String {
        if schedule.mode == .focusRoom {
            let count = schedule.allowedDomains.count + schedule.allowedApps.count
            return "Focus Room · \(count) allowed"
        }
        let names = schedule.blocklistIDs.compactMap { id in
            model.policy.blocklists.first { $0.id == id }?.name
        }
        return names.isEmpty ? "No room" : names.joined(separator: ", ")
    }
}

struct ScheduleRow: View {
    let schedule: WeeklySchedule
    let blocklistName: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(schedule.isEnabled ? FermoTheme.accent : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(schedule.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(schedule.weekdaySummary) at \(String(format: "%02d:%02d", schedule.startHour, schedule.startMinute)) · \(Int(schedule.duration / 60)) min · \(blocklistName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            FermoStatusBadge(label: schedule.isEnabled ? (schedule.lockedMode ? "Locked" : "Soft") : "Off", tone: schedule.isEnabled ? (schedule.lockedMode ? .warning : .muted) : .muted)
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 10)
    }
}

struct PresetPreview: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(FermoTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(FermoTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension Weekday {
    var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }
}

extension WeeklySchedule {
    var weekdaySummary: String {
        Weekday.allCases
            .filter { weekdays.contains($0) }
            .map(\.shortName)
            .joined(separator: ", ")
    }
}
