import Foundation
import SwiftData

@MainActor
enum JournalStore {
    static func add(text: String,
                    tradition: Tradition = .secular,
                    suttaID: String? = nil,
                    planID: UUID? = nil,
                    in context: ModelContext) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = JournalEntry(
            date: .now,
            text: trimmed,
            traditionRaw: tradition.rawValue,
            suttaID: suttaID,
            planID: planID
        )
        context.insert(entry)
        try? context.save()
    }

    static func entries(on date: Date, in context: ModelContext) -> [JournalEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func delete(_ entry: JournalEntry, in context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }
}
