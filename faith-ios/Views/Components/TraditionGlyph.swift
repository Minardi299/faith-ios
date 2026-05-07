import SwiftUI

/// Top-left glyph: a hairline + the tradition name in italic serif.
/// Per design — the only chrome other than the date.
struct TraditionGlyph: View {
    let tradition: Tradition
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(tradition.accent)
                .frame(width: 14, height: 1)
            Text(tradition.name)
                .font(BTFont.serif(13, weight: .light, italic: true))
                .foregroundStyle(theme.inkSoft)
        }
    }
}

struct DateGlyph: View {
    var date: Date = .now
    @Environment(\.theme) private var theme
    var body: some View {
        Text(date, format: .dateTime.day().month(.abbreviated))
            .font(BTFont.ui(11, weight: .light))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(theme.inkMute)
    }
}
