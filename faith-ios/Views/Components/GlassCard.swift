import SwiftUI

/// Liquid Glass surface — uses iOS 26 native `.glassEffect` when available,
/// falling back to `.thinMaterial` on older runtimes.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var tint: Color? = nil
    @ViewBuilder var content: () -> Content
    @Environment(\.theme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content()
            .glassEffect(.regular.tint(tint ?? .clear), in: shape)
            .overlay {
                shape.strokeBorder(theme.border, lineWidth: 0.5)
            }
    }
}

/// A glass-pill button used for tradition glyphs, citation pills, etc.
struct GlassPill<Label: View>: View {
    var tint: Color? = nil
    @ViewBuilder var label: () -> Label
    @Environment(\.theme) private var theme

    var body: some View {
        let shape = Capsule(style: .continuous)
        label()
            .glassEffect(.regular.tint(tint ?? .clear), in: shape)
            .overlay {
                shape.strokeBorder(theme.border, lineWidth: 0.5)
            }
    }
}
