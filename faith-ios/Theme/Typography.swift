import SwiftUI

/// Typography. The chassis design uses `.system(design: .serif)` for
/// headings and body copy. `BTFont` is a thin wrapper around the system
/// serif so older call sites (`BTFont.serif(20, weight: .light)`) keep
/// rendering as the chassis's serif look in cream / dusk variants.
enum BTFont {
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        var f: Font = .system(size: size, weight: weight, design: .serif)
        if italic { f = f.italic() }
        return f
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
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
