import SwiftUI

enum Palette: String, CaseIterable, Identifiable, Codable {
    case moss
    case saffron
    case lotus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .moss: "Moss & Cinnabar"
        case .saffron: "Saffron & Indigo"
        case .lotus: "Lotus & Lake"
        }
    }

    var tagline: String {
        switch self {
        case .moss: "Garden at dusk · sage, cinnabar, sand"
        case .saffron: "Thangka palette · saffron, indigo, jade"
        case .lotus: "Sunset on water · lotus, teal, gold"
        }
    }

    func theme(for colorScheme: ColorScheme) -> Theme {
        switch (self, colorScheme) {
        case (.moss, .dark):    return .mossDusk
        case (.moss, .light):   return .mossDay
        case (.saffron, .dark): return .saffronDusk
        case (.saffron, .light):return .saffronDay
        case (.lotus, .dark):   return .lotusDusk
        case (.lotus, .light):  return .lotusDay
        @unknown default:       return .mossDusk
        }
    }
}

struct Theme {
    let bg: Color
    let bgSoft: Color
    let card: Color
    let cardSoft: Color
    let ink: Color
    let inkSoft: Color
    let inkMute: Color
    let inkFaint: Color
    let accent: Color
    let accentSoft: Color
    let accentInk: Color
    let secondary: Color
    let secondarySoft: Color
    let tertiary: Color
    let tertiarySoft: Color
    let border: Color
}

extension Theme {
    static let mossDusk = Theme(
        bg:         Color(hex: 0x1E2A22),
        bgSoft:     Color(hex: 0x243228),
        card:       Color(hex: 0x2C3A2F),
        cardSoft:   Color(hex: 0x354539),
        ink:        Color(hex: 0xEAEDD8),
        inkSoft:    Color(hex: 0xBFC4A8),
        inkMute:    Color(hex: 0x888E72),
        inkFaint:   Color(hex: 0x525847),
        accent:     Color(hex: 0x9DBE7C),
        accentSoft: Color(hex: 0x9DBE7C, opacity: 0.20),
        accentInk:  Color(hex: 0xC0DA9F),
        secondary:  Color(hex: 0xD8553D),
        secondarySoft: Color(hex: 0xD8553D, opacity: 0.20),
        tertiary:   Color(hex: 0xE8C77D),
        tertiarySoft: Color(hex: 0xE8C77D, opacity: 0.20),
        border:     Color.white.opacity(0.10)
    )

    static let mossDay = Theme(
        bg:         Color(hex: 0xEFEAD2),
        bgSoft:     Color(hex: 0xE5DEBE),
        card:       Color(hex: 0xF8F2D8),
        cardSoft:   Color(hex: 0xECE3C2),
        ink:        Color(hex: 0x243018),
        inkSoft:    Color(hex: 0x4F5A3A),
        inkMute:    Color(hex: 0x838868),
        inkFaint:   Color(hex: 0xB5B898),
        accent:     Color(hex: 0x5A7A3E),
        accentSoft: Color(hex: 0x5A7A3E, opacity: 0.16),
        accentInk:  Color(hex: 0x3A5424),
        secondary:  Color(hex: 0xB33A24),
        secondarySoft: Color(hex: 0xB33A24, opacity: 0.14),
        tertiary:   Color(hex: 0xB98942),
        tertiarySoft: Color(hex: 0xB98942, opacity: 0.16),
        border:     Color.black.opacity(0.10)
    )

    static let saffronDusk = Theme(
        bg:         Color(hex: 0x1A1F38),
        bgSoft:     Color(hex: 0x22284A),
        card:       Color(hex: 0x2A3258),
        cardSoft:   Color(hex: 0x343D6A),
        ink:        Color(hex: 0xF4E8CE),
        inkSoft:    Color(hex: 0xC9BC9C),
        inkMute:    Color(hex: 0x8A8270),
        inkFaint:   Color(hex: 0x5A5448),
        accent:     Color(hex: 0xE89A3C),
        accentSoft: Color(hex: 0xE89A3C, opacity: 0.20),
        accentInk:  Color(hex: 0xF4BD7A),
        secondary:  Color(hex: 0x7DB099),
        secondarySoft: Color(hex: 0x7DB099, opacity: 0.18),
        tertiary:   Color(hex: 0xC84F4F),
        tertiarySoft: Color(hex: 0xC84F4F, opacity: 0.18),
        border:     Color.white.opacity(0.10)
    )

    static let saffronDay = Theme(
        bg:         Color(hex: 0xF1E4C8),
        bgSoft:     Color(hex: 0xE8D6B0),
        card:       Color(hex: 0xFAEED2),
        cardSoft:   Color(hex: 0xEFDDB6),
        ink:        Color(hex: 0x1F2447),
        inkSoft:    Color(hex: 0x4D5478),
        inkMute:    Color(hex: 0x8A8567),
        inkFaint:   Color(hex: 0xC0B697),
        accent:     Color(hex: 0xC97320),
        accentSoft: Color(hex: 0xC97320, opacity: 0.16),
        accentInk:  Color(hex: 0x8A4D14),
        secondary:  Color(hex: 0x3E6B5B),
        secondarySoft: Color(hex: 0x3E6B5B, opacity: 0.16),
        tertiary:   Color(hex: 0xA03838),
        tertiarySoft: Color(hex: 0xA03838, opacity: 0.16),
        border:     Color.black.opacity(0.10)
    )

    static let lotusDusk = Theme(
        bg:         Color(hex: 0x2C1E2C),
        bgSoft:     Color(hex: 0x352436),
        card:       Color(hex: 0x3F2B40),
        cardSoft:   Color(hex: 0x4B344C),
        ink:        Color(hex: 0xF2E2DA),
        inkSoft:    Color(hex: 0xCDB8B5),
        inkMute:    Color(hex: 0x8E7B82),
        inkFaint:   Color(hex: 0x594A56),
        accent:     Color(hex: 0xE07AA0),
        accentSoft: Color(hex: 0xE07AA0, opacity: 0.20),
        accentInk:  Color(hex: 0xF2A8C2),
        secondary:  Color(hex: 0x5BA8A8),
        secondarySoft: Color(hex: 0x5BA8A8, opacity: 0.20),
        tertiary:   Color(hex: 0xF1C24A),
        tertiarySoft: Color(hex: 0xF1C24A, opacity: 0.20),
        border:     Color.white.opacity(0.10)
    )

    static let lotusDay = Theme(
        bg:         Color(hex: 0xF4E6E0),
        bgSoft:     Color(hex: 0xEBD5CE),
        card:       Color(hex: 0xFBEEE9),
        cardSoft:   Color(hex: 0xF0DDD5),
        ink:        Color(hex: 0x3A1F2F),
        inkSoft:    Color(hex: 0x6E4458),
        inkMute:    Color(hex: 0xA07882),
        inkFaint:   Color(hex: 0xD0B5BB),
        accent:     Color(hex: 0xB84878),
        accentSoft: Color(hex: 0xB84878, opacity: 0.14),
        accentInk:  Color(hex: 0x7A2E50),
        secondary:  Color(hex: 0x2E7878),
        secondarySoft: Color(hex: 0x2E7878, opacity: 0.14),
        tertiary:   Color(hex: 0xC28818),
        tertiarySoft: Color(hex: 0xC28818, opacity: 0.16),
        border:     Color.black.opacity(0.10)
    )
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .mossDusk
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
