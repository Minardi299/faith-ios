import SwiftUI

enum Tradition: String, CaseIterable, Identifiable, Codable, Hashable {
    case theravada
    case mahayana
    case vajrayana
    case zen
    case secular

    var id: String { rawValue }

    var name: String {
        switch self {
        case .theravada: "Theravāda"
        case .mahayana:  "Mahāyāna"
        case .vajrayana: "Vajrayāna"
        case .zen:       "Zen"
        case .secular:   "Secular"
        }
    }

    var pali: String {
        switch self {
        case .theravada: "Path of the Elders"
        case .mahayana:  "The Great Vehicle"
        case .vajrayana: "The Diamond Vehicle"
        case .zen:       "Sitting. Just this."
        case .secular:   "Practice without lineage"
        }
    }

    var blurb: String {
        switch self {
        case .theravada: "Forest monasteries. Pāli canon. Mettā and the breath."
        case .mahayana:  "Bodhicitta. The sūtras. East Asian mountain mist."
        case .vajrayana: "Himalayan tradition. Mantra, deity, sky."
        case .zen:       "Sōtō and Rinzai. Sumi ink. The bamboo, the stone."
        case .secular:   "The teachings as a way of attention. No metaphysics required."
        }
    }

    var canonName: String {
        switch self {
        case .theravada: "Pāli Canon (Tipiṭaka)"
        case .mahayana:  "Mahāyāna Sūtras"
        case .vajrayana: "Tibetan Canon"
        case .zen:       "Zen Texts"
        case .secular:   "Without Lineage"
        }
    }

    var accent: Color {
        // Prefer named colors from the asset catalog; fall back to hex defaults.
        let named: String
        let fallback: UInt32
        switch self {
        case .theravada: named = "AccentTheravada"; fallback = 0xC9772D
        case .mahayana:  named = "AccentMahayana";  fallback = 0x384E8A
        case .vajrayana: named = "AccentVajrayana"; fallback = 0x9C2A1F
        case .zen:       named = "AccentZen";       fallback = 0xF5F0E8
        case .secular:   named = "AccentSecular";   fallback = 0x5C7A6E
        }
        if UIColor(named: named) != nil {
            return Color(named, bundle: .main)
        }
        return Color(hex: fallback)
    }

    var accentName: String {
        switch self {
        case .theravada: "saffron"
        case .mahayana:  "indigo"
        case .vajrayana: "crimson"
        case .zen:       "washi"
        case .secular:   "sage"
        }
    }

    /// Two-stop substrate gradient that hints at the tradition's natural setting.
    /// Used in place of photographed nature until M13d art-direction pass.
    var substrateGradient: Gradient {
        switch self {
        case .theravada:
            // golden forest dawn, warm amber
            return Gradient(colors: [
                Color(hex: 0x4A2E14),
                Color(hex: 0x1A0F08)
            ])
        case .mahayana:
            // East Asian mountain mist, indigo-grey
            return Gradient(colors: [
                Color(hex: 0x1F2840),
                Color(hex: 0x0A0E1A)
            ])
        case .vajrayana:
            // Himalayan first light
            return Gradient(colors: [
                Color(hex: 0x3A1410),
                Color(hex: 0x100808)
            ])
        case .zen:
            // sumi-ink garden, near-black
            return Gradient(colors: [
                Color(hex: 0x1A1A1A),
                Color(hex: 0x050505)
            ])
        case .secular:
            // sage, soft fog
            return Gradient(colors: [
                Color(hex: 0x1F2D26),
                Color(hex: 0x0A100D)
            ])
        }
    }
}

// Color(hex:opacity:) lives in Theme.swift.

