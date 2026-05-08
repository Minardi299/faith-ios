import Foundation

/// Multi-year buddhist observance calendar. Curated lunar-based dates for
/// 2026–2028; movable feasts use Foundation.Calendar where possible.
enum HolyDayCalendar {
    /// Static lunar/major holiday dates. Map of (year, month, day) → entry.
    /// Sources: Vesak/Wesak (Theravāda full moon Vaisakha), Bodhi Day (Dec 8 ZEN),
    /// Losar (Tibetan new year), Saga Dawa (Tibetan Vesak — full moon 4th lunar),
    /// Rōhatsu (Dec 1–8 sesshin, 8th = enlightenment), Hanamatsuri (Apr 8 Buddha's birthday),
    /// Magha Puja, Kathina end, etc.
    private static let staticHolidays: [(year: Int, month: Int, day: Int, kind: HolyDay.Kind, label: String, subtitle: String?, tradition: String?)] = [
        // 2026
        (2026, 2, 17, .major,     "Magha Puja",       "1,250 disciples gather",            "theravada"),
        (2026, 2, 18, .major,     "Losar",            "Tibetan New Year",                  "vajrayana"),
        (2026, 4,  8, .major,     "Hanamatsuri",      "Buddha's birthday",                 "mahayana"),
        (2026, 5, 31, .major,     "Vesak",            "Birth, awakening, parinirvāṇa",     "theravada"),
        (2026, 5, 31, .major,     "Saga Dawa",        "Sacred month begins",               "vajrayana"),
        (2026, 7, 30, .major,     "Asalha Puja",      "First sermon · Rains begin",        "theravada"),
        (2026, 9,  1, .observance,"Pavarana",         "Rains end · invitation",            "theravada"),
        (2026,10, 26, .observance,"Kaṭhina ends",     nil,                                 "theravada"),
        (2026,11, 17, .memorial,  "Patriarch Linji's Death", nil,                          "zen"),
        (2026,11, 22, .memorial,  "Bodhidharma's Memorial",  nil,                          "zen"),
        (2026,11, 24, .major,     "Anāpānasati Day",  "The Buddha praises the breath",     "theravada"),
        (2026,11, 28, .memorial,  "Tsongkhapa's Birth", nil,                                "vajrayana"),
        (2026,12,  1, .major,     "Rōhatsu sesshin",  "Week of intensive sitting",         "zen"),
        (2026,12,  8, .major,     "Bodhi Day",        "The Buddha's awakening",            "zen"),
        // 2027
        (2027, 2,  7, .major,     "Losar",            "Tibetan New Year",                  "vajrayana"),
        (2027, 4,  8, .major,     "Hanamatsuri",      "Buddha's birthday",                 "mahayana"),
        (2027, 5, 20, .major,     "Vesak",            "Birth, awakening, parinirvāṇa",     "theravada"),
        (2027, 5, 20, .major,     "Saga Dawa",        "Sacred month begins",               "vajrayana"),
        (2027, 7, 19, .major,     "Asalha Puja",      "First sermon",                      "theravada"),
        (2027,12,  8, .major,     "Bodhi Day",        "The Buddha's awakening",            "zen"),
        // 2028
        (2028, 2, 26, .major,     "Losar",            "Tibetan New Year",                  "vajrayana"),
        (2028, 4,  8, .major,     "Hanamatsuri",      "Buddha's birthday",                 "mahayana"),
        (2028, 5,  9, .major,     "Vesak",            "Birth, awakening, parinirvāṇa",     "theravada"),
        (2028, 5,  9, .major,     "Saga Dawa",        "Sacred month begins",               "vajrayana"),
        (2028,12,  8, .major,     "Bodhi Day",        "The Buddha's awakening",            "zen"),
    ]

    /// Returns observances for a given month, including auto-derived uposatha
    /// days (full + new moons) for Theravāda.
    static func observances(year: Int, month: Int) -> [HolyDay] {
        var out = staticHolidays
            .filter { $0.year == year && $0.month == month }
            .map { entry in
                HolyDay(id: UUID(),
                        day: entry.day,
                        month: entry.month,
                        year: entry.year,
                        kind: entry.kind,
                        label: entry.label,
                        subtitle: entry.subtitle,
                        traditionRaw: entry.tradition)
            }

        // Auto-add uposatha days (full + new moon)
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
        guard let firstDay = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstDay) else { return out }
        for d in range {
            comps.day = d
            guard let date = cal.date(from: comps) else { continue }
            switch LunarPhaseCalculator.phase(for: date) {
            case .fullMoon:
                if !out.contains(where: { $0.day == d && $0.label.lowercased().contains("uposatha") }) {
                    out.append(HolyDay(id: UUID(), day: d, month: month, year: year,
                                       kind: .uposatha,
                                       label: "Full-Moon Uposatha",
                                       subtitle: nil,
                                       traditionRaw: "theravada"))
                }
            case .newMoon:
                if !out.contains(where: { $0.day == d && $0.label.lowercased().contains("uposatha") }) {
                    out.append(HolyDay(id: UUID(), day: d, month: month, year: year,
                                       kind: .uposatha,
                                       label: "New-Moon Uposatha",
                                       subtitle: nil,
                                       traditionRaw: "theravada"))
                }
            default:
                break
            }
        }
        return out
    }

    static func lunarPhases(year: Int, month: Int) -> [Int: LunarPhase] {
        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = 1
        guard let firstDay = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstDay) else { return [:] }
        var result: [Int: LunarPhase] = [:]
        for d in range {
            comps.day = d
            guard let date = cal.date(from: comps) else { continue }
            let phase = LunarPhaseCalculator.phase(for: date)
            if phase != .none { result[d] = phase }
        }
        return result
    }
}
