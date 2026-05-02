import Foundation
import SwiftData

@MainActor
struct ProgressStore {
    let context: ModelContext

    @discardableResult
    func ensureToday(date: Date = .now) -> DayCompletion {
        let key = DayCompletion.key(for: date)
        let descriptor = FetchDescriptor<DayCompletion>(
            predicate: #Predicate { $0.dayKey == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let new = DayCompletion(date: date)
        context.insert(new)
        return new
    }

    func markMeditationDone(date: Date = .now) {
        ensureToday(date: date).meditationDone = true
    }

    /// Returns the current consecutive-day streak ending today (or yesterday if today not yet complete).
    func currentStreak(now: Date = .now) -> Int {
        let calendar = Calendar.current
        let descriptor = FetchDescriptor<DayCompletion>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor) else { return 0 }
        let completedDays = Set(
            all.filter { $0.isComplete }.map { calendar.startOfDay(for: $0.date) }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        if !completedDays.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while completedDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Returns the 7 days for the week containing `date` (Monday-first), each with its completion (or nil).
    func week(containing date: Date = .now) -> [(date: Date, completion: DayCompletion?)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: today)
        let offsetFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -offsetFromMonday, to: today) else {
            return []
        }
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
        let keys = days.map { DayCompletion.key(for: $0) }
        let descriptor = FetchDescriptor<DayCompletion>(
            predicate: #Predicate { keys.contains($0.dayKey) }
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        let byKey = Dictionary(uniqueKeysWithValues: fetched.map { ($0.dayKey, $0) })
        return days.map { ($0, byKey[DayCompletion.key(for: $0)]) }
    }
}
