import Foundation
import SwiftData

@MainActor
enum AnniversaryStore {
    static func add(day: Int,
                    month: Int,
                    year: Int,
                    label: String,
                    tradition: Tradition? = nil,
                    repeatsYearly: Bool = true,
                    in context: ModelContext) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = Anniversary(
            day: day, month: month, year: year,
            label: trimmed,
            traditionRaw: tradition?.rawValue,
            repeatsYearly: repeatsYearly
        )
        context.insert(item)
        try? context.save()
    }

    static func delete(_ ann: Anniversary, in context: ModelContext) {
        context.delete(ann)
        try? context.save()
    }

    static func all(in context: ModelContext) -> [Anniversary] {
        let descriptor = FetchDescriptor<Anniversary>(
            sortBy: [SortDescriptor(\.month), SortDescriptor(\.day)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func matches(day: Int, month: Int, year: Int, in context: ModelContext) -> [Anniversary] {
        let descriptor = FetchDescriptor<Anniversary>(
            predicate: #Predicate { $0.month == month && $0.day == day },
            sortBy: [SortDescriptor(\.year)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.matches(day: day, month: month, year: year) }
    }
}
