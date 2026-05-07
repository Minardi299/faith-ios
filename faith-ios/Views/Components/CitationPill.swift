import SwiftUI

/// Inline glass pill used mid-sentence in chat / sutta detail.
/// Reads as type, not UI.
struct CitationPill: View {
    let cite: SuttaCite
    var onTap: (SuttaCite) -> Void = { _ in }
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            onTap(cite)
        } label: {
            HStack(spacing: 6) {
                Text(cite.code)
                    .font(BTFont.ui(11.5, weight: .regular))
                    .foregroundStyle(theme.ink)
                Text("·")
                    .foregroundStyle(theme.inkMute)
                Text(cite.englishTitle)
                    .font(BTFont.serif(11.5, weight: .light, italic: true))
                    .foregroundStyle(theme.inkSoft)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
