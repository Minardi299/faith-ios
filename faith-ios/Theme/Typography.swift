import SwiftUI

/// Typography. The chassis design uses `.system(design: .serif)` for
/// headings and body copy. `BTFont` is a thin wrapper around the system
/// serif so older call sites (`BTFont.serif(20, weight: .light)`) keep
/// rendering as the chassis's serif look in cream / dusk variants.
///
/// Fonts are mapped to `Font.TextStyle` buckets so they scale with
/// Dynamic Type. The mapping is approximate — each bucket uses the
/// TextStyle whose default size is closest to the requested CGFloat.
enum BTFont {
    /// Maps a numeric point size to a SwiftUI Font.TextStyle bucket so
    /// callers' existing CGFloat arguments produce fonts that scale with
    /// Dynamic Type. The mapping is approximate — pick the TextStyle whose
    /// default size is closest to the requested CGFloat.
    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5:  return .caption2     // ~11pt default
        case ..<12.5:  return .caption       // ~12pt default
        case ..<13.5:  return .footnote      // ~13pt default
        case ..<15.5:  return .subheadline   // ~15pt default
        case ..<17.5:  return .body          // ~17pt default
        case ..<19.5:  return .callout       // ~16pt default but the next anchor is 20
        case ..<22.5:  return .title3        // ~20pt default
        case ..<27.5:  return .title2        // ~22pt default
        case ..<33.5:  return .title         // ~28pt default
        default:       return .largeTitle    // ~34pt default
        }
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        var f: Font = .system(textStyle(for: size), design: .serif).weight(weight)
        if italic { f = f.italic() }
        return f
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .default).weight(weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(textStyle(for: size), design: .monospaced).weight(weight)
    }
}

extension View {
    /// Small uppercase eyebrow line. The palette tint comes from the
    /// surrounding `theme.inkMute`; `.eyebrow()` itself is purely typographic.
    func eyebrow() -> some View {
        self
            .font(BTFont.ui(10.5, weight: .semibold))
            .tracking(2)
            .textCase(.uppercase)
    }
}
