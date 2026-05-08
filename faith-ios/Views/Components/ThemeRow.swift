import SwiftUI

/// A theme picker row used by Onboarding's `ThemePickerStep` and by the
/// Settings switch-theme sheet. Renders a substrate-gradient swatch + name +
/// short blurb + selection dot.
struct ThemeRow: View {
    let tradition: Tradition
    let selected: Bool
    let onTap: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(gradient: tradition.substrateGradient,
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(theme.border, lineWidth: 0.5)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(tradition.name)
                        .font(BTFont.serif(17, weight: .light))
                        .foregroundStyle(theme.ink)
                    Text(tradition.blurb)
                        .font(BTFont.ui(11, weight: .light))
                        .foregroundStyle(theme.inkMute)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if selected {
                    Circle()
                        .fill(tradition.accent)
                        .frame(width: 8, height: 8)
                        .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(selected ? .regular.tint(theme.border) : .regular,
                          in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
