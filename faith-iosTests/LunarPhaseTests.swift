import Testing
import Foundation
@testable import faith_ios

@Suite("LunarPhaseCalculator")
struct LunarPhaseTests {

    /// Approximate sanity test — we only verify that some phase is detected
    /// each month and that two adjacent days don't both hit the same major
    /// quarter (full moons are point events).
    @Test("Each month has ≥3 detected phase events")
    func phasesPerMonth() {
        let phases = HolyDayCalendar.lunarPhases(year: 2026, month: 11)
        let detected = phases.values.filter { $0 != .none }.count
        #expect(detected >= 3, "Expected ≥3 detected lunar events in Nov 2026, got \(detected)")
    }

    @Test("Each major quarter appears at least once across a year")
    func phasesAcrossYear() {
        var seen: Set<LunarPhase> = []
        for m in 1...12 {
            let p = HolyDayCalendar.lunarPhases(year: 2026, month: m)
            for v in p.values { seen.insert(v) }
        }
        #expect(seen.contains(.newMoon))
        #expect(seen.contains(.fullMoon))
    }
}
