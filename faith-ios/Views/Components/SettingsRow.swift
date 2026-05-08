import SwiftUI

/// Reusable row + section primitives lifted out of the old MoreView so
/// PracticeView and SettingsView (and any future settings-style screen) can
/// compose them without re-inventing the chrome. Each helper returns a
/// dedicated `View` struct so it can read the chassis `Theme` from the
/// SwiftUI environment.
@MainActor
enum SettingsRow {

    @ViewBuilder
    static func section<Content: View>(_ title: String,
                                       @ViewBuilder content: () -> Content) -> some View {
        SettingsSection(title: title, content: content())
    }

    @ViewBuilder
    static func nav(_ title: String,
                    value: String? = nil,
                    accent: Color? = nil,
                    icon: String? = nil,
                    action: (() -> Void)? = nil) -> some View {
        SettingsNavRow(title: title, value: value, accent: accent, icon: icon, action: action)
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.theme) private var theme

    init(title: String, content: Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .eyebrow()
                .foregroundStyle(theme.inkMute)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.border, lineWidth: 0.5)
            )
        }
    }
}

private struct SettingsNavRow: View {
    let title: String
    let value: String?
    let accent: Color?
    let icon: String?
    let action: (() -> Void)?

    @Environment(\.theme) private var theme

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(theme.inkSoft)
                }
                Text(title)
                    .font(BTFont.serif(15, weight: .regular))
                    .foregroundStyle(theme.ink)
                Spacer()
                if let accent {
                    Circle().fill(accent).frame(width: 6, height: 6)
                }
                if let value {
                    Text(value)
                        .font(BTFont.ui(12, weight: .regular))
                        .foregroundStyle(theme.inkMute)
                }
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(theme.inkMute)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
