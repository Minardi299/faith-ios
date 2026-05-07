import Foundation

/// Approximate lunar phase from a known new-moon reference and the synodic
/// period. Within ~1 day of true ephemeris — adequate for showing major
/// quarters in a calendar grid.
enum LunarPhaseCalculator {
    /// Reference new moon: 2000-01-06 18:14 UTC.
    private static let referenceNewMoon: TimeInterval = 947182440
    /// Synodic month in seconds.
    private static let synodicSeconds: Double = 29.530588853 * 86400

    static func phase(for date: Date) -> LunarPhase {
        let elapsed = date.timeIntervalSince1970 - referenceNewMoon
        let positiveElapsed = elapsed >= 0 ? elapsed : (elapsed + ceil(-elapsed / synodicSeconds) * synodicSeconds)
        let fraction = positiveElapsed.truncatingRemainder(dividingBy: synodicSeconds) / synodicSeconds
        // Quarters get a window of ~1.5 days each, so the calendar is more useful.
        let dayWindow = 1.6 / 29.530588853   // ≈ 0.054
        if fraction < dayWindow || fraction > 1 - dayWindow { return .newMoon }
        if abs(fraction - 0.25) < dayWindow { return .firstQuarter }
        if abs(fraction - 0.5)  < dayWindow { return .fullMoon }
        if abs(fraction - 0.75) < dayWindow { return .lastQuarter }
        return .none
    }
}
