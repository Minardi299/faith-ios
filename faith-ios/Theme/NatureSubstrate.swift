import SwiftUI

/// Page background aligned with the chassis `Theme` palette. Renders
/// `theme.bg` with a soft tradition-accent wash in the upper-right corner
/// so reading rooms (SuttaDetailSheet, ChatView, MeditateView) match
/// Today / Practice / Library. `tradition` is preserved as a hint for
/// the accent tint.
struct NatureSubstrate: View {
    var tradition: Tradition = .secular
    var dimming: Double = 0.0

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            theme.bg

            // Soft accent wash near the top-right — keeps a subtle sense of
            // place per tradition without committing to a dark substrate.
            RadialGradient(
                colors: [tradition.accent.opacity(0.10), .clear],
                center: UnitPoint(x: 0.78, y: 0.14),
                startRadius: 12,
                endRadius: 360
            )

            if dimming > 0 {
                Color.black.opacity(dimming * 0.25)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    NatureSubstrate(tradition: .zen)
        .environment(\.theme, .mossDay)
}
