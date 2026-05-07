import Foundation

struct HolyDay: Identifiable, Hashable, Codable {
    enum Kind: String, Codable, Hashable {
        case major
        case uposatha
        case memorial
        case observance
        case personal
    }

    let id: UUID
    let day: Int                // gregorian day of month
    let month: Int
    let year: Int
    let kind: Kind
    let label: String
    let subtitle: String?
    let traditionRaw: String?   // nil = personal

    var tradition: Tradition? {
        guard let raw = traditionRaw else { return nil }
        return Tradition(rawValue: raw)
    }
}

enum LunarPhase: String, Codable, Hashable {
    case newMoon, firstQuarter, fullMoon, lastQuarter, none

    var glyph: String {
        switch self {
        case .newMoon:      "moonphase.new.moon"
        case .firstQuarter: "moonphase.first.quarter"
        case .fullMoon:     "moonphase.full.moon"
        case .lastQuarter:  "moonphase.last.quarter"
        case .none:         ""
        }
    }
}
