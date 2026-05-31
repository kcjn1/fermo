import SwiftUI

enum FermoTheme {
    static let background = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let panel = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let panelRaised = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let line = Color.white.opacity(0.08)
    static let accent = Color(red: 0.39, green: 0.82, blue: 0.68)
    static let warning = Color(red: 0.92, green: 0.65, blue: 0.28)
    static let danger = Color(red: 0.88, green: 0.34, blue: 0.28)
    static let mutedText = Color.secondary
}

struct FermoScreen<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                content
            }
            .padding(24)
            .frame(maxWidth: 1040, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

struct FermoPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String?
    @ViewBuilder var content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        symbol: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                if let symbol {
                    Image(systemName: symbol)
                        .foregroundStyle(FermoTheme.accent)
                        .frame(width: 18)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            content
        }
        .padding(16)
        .background(FermoTheme.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FermoTheme.line)
        )
    }
}

struct FermoStatusBadge: View {
    enum Tone {
        case ok
        case info
        case warning
        case danger
        case muted

        var color: Color {
            switch self {
            case .ok: FermoTheme.accent
            case .info: .blue
            case .warning: FermoTheme.warning
            case .danger: FermoTheme.danger
            case .muted: .secondary
            }
        }
    }

    let label: String
    var tone: Tone = .ok

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tone.color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(tone.color)
        .background(tone.color.opacity(0.14))
        .clipShape(Capsule())
    }
}

struct FermoStatusStrip: View {
    let label: String
    let reason: String
    let tone: FermoStatusBadge.Tone
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: tone == .warning ? "exclamationmark.triangle" : "lock.shield")
                .foregroundStyle(tone.color)
            VStack(alignment: .leading, spacing: 3) {
                FermoStatusBadge(label: label, tone: tone)
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(tone.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.color.opacity(0.28))
        )
    }
}

/// First-run / empty surface card: icon chip, title, honest body copy, optional dashed
/// illustration stripe, and one or two CTAs. Matches the accepted design's StateCard.
struct FermoEmptyStateCard: View {
    let symbol: String
    var tone: FermoStatusBadge.Tone = .muted
    let title: String
    let message: String
    var illustrationLabel: String?
    var primaryTitle: String?
    var primaryAction: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(tone.color)
                    .frame(width: 30, height: 30)
                    .background(tone.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(tone.color.opacity(0.35)))
                Text(title).font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            }
            if let illustrationLabel {
                Text(illustrationLabel.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(FermoTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            }
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if primaryTitle != nil || secondaryTitle != nil {
                HStack(spacing: 8) {
                    if let primaryTitle, let primaryAction {
                        Button(primaryTitle, action: primaryAction)
                            .buttonStyle(.borderedProminent)
                            .tint(FermoTheme.accent)
                    }
                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FermoTheme.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(FermoTheme.line))
    }
}

/// A tappable card used for mutually-exclusive choices (e.g. proof outcome).
struct FermoSelectableCard: View {
    let symbol: String
    let title: String
    let detail: String
    let isSelected: Bool
    var tone: FermoStatusBadge.Tone = .ok
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(isSelected ? tone.color : .secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isSelected ? tone.color.opacity(0.14) : FermoTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? tone.color.opacity(0.6) : FermoTheme.line)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A capsule filter toggle used in the Evidence toolbar.
struct FermoFilterPill: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isActive ? FermoTheme.accent : Color.secondary)
                .background(isActive ? FermoTheme.accent.opacity(0.18) : FermoTheme.panel)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? FermoTheme.accent.opacity(0.5) : FermoTheme.line))
        }
        .buttonStyle(.plain)
    }
}

/// A monospaced live Markdown preview card with a filename header.
struct FermoMarkdownPreview: View {
    let filename: String
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text").foregroundStyle(.secondary)
                Text(filename)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                Text(markdown)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 160, maxHeight: 300)
        }
        .padding(12)
        .background(FermoTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(FermoTheme.line))
    }
}

struct FermoMetric: View {
    let label: String
    let value: String
    let symbol: String
    var tone: FermoStatusBadge.Tone = .ok

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tone.color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(FermoTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
