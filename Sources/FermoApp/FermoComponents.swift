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
