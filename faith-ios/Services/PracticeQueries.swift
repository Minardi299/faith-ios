import Foundation
import SwiftData

/// Read/write helpers over `PracticeRecord` rows. The schema only tracks
/// sits now (reading-tracker was killed) but the kind column is preserved
/// for future practice types (e.g. "chant").
@MainActor
enum PracticeQueries {

    static func recordSit(minutes: Int, in context: ModelContext) {
        let record = PracticeRecord(day: .now, kindRaw: PracticeRecord.Kind.sit.rawValue, minutes: minutes)
        context.insert(record)
        try? context.save()
    }

    /// Sum of sit minutes recorded today.
    static func minutesSatToday(in context: ModelContext) -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<PracticeRecord>(
            predicate: #Predicate { $0.day == start && $0.kindRaw == "sit" }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.reduce(0) { $0 + $1.minutes }
    }

    /// Number of consecutive days (working backwards from today) with at
    /// least one practice record. A day with no record breaks the streak.
    static func currentStreak(in context: ModelContext) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let descriptor = FetchDescriptor<PracticeRecord>(
            sortBy: [SortDescriptor(\.day, order: .reverse)]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        let practicedDays = Set(rows.map { cal.startOfDay(for: $0.day) })

        var streak = 0
        var cursor = today
        while practicedDays.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Composite "tasks completed today" — counts the 5 DayCompletion flags
    /// PLUS treats meditationDone as TRUE if any PracticeRecord sit exists for today.
    /// This prevents the user from having to double-tap (sit timer + checkbox)
    /// just to register that they meditated.
    ///
    /// NOTE: The meditation OR-clause uses `minutesSatToday(in:)` which always checks
    /// today's sits. Calling this for a non-today date will still give the correct
    /// checklist count but the meditation OR won't apply to that past date correctly.
    /// For Phase 5.7's primary use case — Today's progress bar — this is fine.
    static func compositeDoneCount(date: Date, in context: ModelContext) -> Int {
        let dayKey = DayCompletion.key(for: date)
        let dc = (try? context.fetch(
            FetchDescriptor<DayCompletion>(
                predicate: #Predicate { $0.dayKey == dayKey }
            )
        ))?.first

        let didMeditateChecklist = dc?.meditationDone ?? false
        let didMeditateActual = minutesSatToday(in: context) > 0
        let didMeditate = didMeditateChecklist || didMeditateActual

        let otherFlags: [Bool] = [
            dc?.morningPrayerDone ?? false,
            dc?.storyReadDone ?? false,
            dc?.gratitudeDone ?? false,
            dc?.eveningReflectionDone ?? false
        ]

        return ([didMeditate] + otherFlags).filter { $0 }.count
    }

    /// Composite progress (0...1).
    static func compositeProgress(date: Date, in context: ModelContext) -> Double {
        Double(compositeDoneCount(date: date, in: context)) / 5.0
    }

    /// Per-day practice "depth" for a given month, used by the calendar
    /// grid: day-of-month → minutes practiced that day.
    static func practiceDepths(year: Int, month: Int, in context: ModelContext) -> [Int: Int] {
        let cal = Calendar.current
        guard
            let monthStart = cal.date(from: DateComponents(year: year, month: month, day: 1)),
            let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)
        else { return [:] }

        let descriptor = FetchDescriptor<PracticeRecord>(
            predicate: #Predicate { $0.day >= monthStart && $0.day < monthEnd }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        var depths: [Int: Int] = [:]
        for r in rows {
            let day = cal.component(.day, from: r.day)
            depths[day, default: 0] += r.minutes
        }
        return depths
    }
}
