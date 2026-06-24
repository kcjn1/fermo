import FermoCore
import SwiftUI

struct FermoRoomsView: View {
    @ObservedObject var model: FermoViewModel
    var onStartContract: () -> Void = {}
    @State private var editingBlocklistID: UUID?
    @State private var editorState = BlocklistEditorState()
    @State private var isEditorVisible = false

    var body: some View {
        FermoScreen(
            title: "Rooms",
            subtitle: "Reusable focus environments: allow what belongs, block what does not."
        ) {
            if model.isRuleWeakeningLocked, let session = model.activeSession {
                FermoStatusStrip(
                    label: "Rules locked",
                    reason: "\(session.rigor.displayName) contract is active. Editing that weakens protection is locked until \(session.endsAt.formatted(date: .omitted, time: .shortened)).",
                    tone: .warning
                )
            }

            FermoPanel("Room Editor", subtitle: isEditorVisible ? editorState.title : "Create or update local rule sets.", symbol: "slider.horizontal.3") {
                if isEditorVisible {
                    BlocklistEditorForm(
                        state: $editorState,
                        isLocked: model.isRuleWeakeningLocked,
                        onSave: {
                            model.saveBlocklist(id: editingBlocklistID, draft: editorState.draft)
                            resetEditor()
                        },
                        onCancel: resetEditor,
                        onDelete: editingBlocklistID.map { id in
                            {
                                model.deleteBlocklist(id: id)
                                resetEditor()
                            }
                        }
                    )
                } else {
                    HStack {
                        Button {
                            beginNewBlocklist()
                        } label: {
                            Label("New Room", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FermoTheme.accent)
                        .disabled(model.isRuleWeakeningLocked)

                        if model.isRuleWeakeningLocked {
                            Button {
                                model.requestRuleWeakeningEdit()
                            } label: {
                                Label("Why Locked?", systemImage: "lock")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if model.policy.blocklists.isEmpty && !isEditorVisible {
                FermoEmptyStateCard(
                    symbol: "square.grid.2x2",
                    tone: .muted,
                    title: "No rooms yet",
                    message: "A room is a saved set of allowed websites and apps, with a default duration and rigor. Start from a preset — Writing, Coding, Admin, Deep Planning — or build one yourself.",
                    illustrationLabel: "Room list · empty",
                    primaryTitle: "Add your first room",
                    primaryAction: { beginNewBlocklist() },
                    secondaryTitle: "Use a preset",
                    secondaryAction: onStartContract
                )
            }

            ForEach(model.policy.blocklists) { blocklist in
                FermoPanel(blocklist.name, subtitle: blocklist.isEnabled ? "Enabled" : "Disabled", symbol: "door.left.hand.closed") {
                    VStack(alignment: .leading, spacing: 12) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            RuleList(title: "Blocked websites", symbol: "globe", items: blocklist.domainRules.map(\.normalizedPattern))
                            RuleList(title: "Blocked apps", symbol: "app.dashed", items: blocklist.appRules.map { "\($0.displayName) · \($0.bundleIdentifier)" })
                        }
                        HStack {
                            Button {
                                beginEditing(blocklist)
                            } label: {
                                Label("Edit Rules", systemImage: "pencil")
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isRuleWeakeningLocked)

                            if model.isRuleWeakeningLocked {
                                Button {
                                    model.requestRuleWeakeningEdit()
                                } label: {
                                    Label("Why Locked?", systemImage: "lock")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            FermoPanel("Locked Session Rule", symbol: "lock") {
                Text("During Locked or Emergency sessions, Fermo routes rule edits through LockedModeGuard before any weakening mutation can proceed.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func beginNewBlocklist() {
        editingBlocklistID = nil
        editorState = BlocklistEditorState()
        isEditorVisible = true
    }

    private func beginEditing(_ blocklist: Blocklist) {
        editingBlocklistID = blocklist.id
        editorState = BlocklistEditorState(blocklist: blocklist)
        isEditorVisible = true
    }

    private func resetEditor() {
        editingBlocklistID = nil
        editorState = BlocklistEditorState()
        isEditorVisible = false
    }
}

struct BlocklistEditorState: Equatable {
    var name = ""
    var domainsText = ""
    var appsText = ""
    var isEnabled = true

    init() {}

    init(blocklist: Blocklist) {
        self.name = blocklist.name
        self.domainsText = blocklist.domainRules.map(\.rawPattern).joined(separator: "\n")
        self.appsText = blocklist.appRules.map(\.bundleIdentifier).joined(separator: "\n")
        self.isEnabled = blocklist.isEnabled
    }

    var title: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Room" : name
    }

    var draft: BlocklistEditorDraft {
        BlocklistEditorDraft(
            name: name,
            domainPatterns: Self.lines(from: domainsText),
            appRules: Self.lines(from: appsText).map { EditableAppRule(bundleIdentifier: $0) },
            isEnabled: isEnabled
        )
    }

    private static func lines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct BlocklistEditorForm: View {
    @Binding var state: BlocklistEditorState
    let isLocked: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Room name", text: $state.name)
            Toggle("Enabled", isOn: $state.isEnabled)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Blocked websites", systemImage: "globe")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $state.domainsText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(FermoTheme.panelRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Blocked apps", systemImage: "app.dashed")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $state.appsText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(FermoTheme.panelRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            HStack {
                Button(action: onSave) {
                    Label("Save Room", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(FermoTheme.accent)
                .disabled(isLocked)

                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark")
                }
                .buttonStyle(.bordered)

                if let onDelete {
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLocked)
                }
            }
        }
    }
}

struct RuleList: View {
    let title: String
    let symbol: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
            if items.isEmpty {
                Text("None recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FermoTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
