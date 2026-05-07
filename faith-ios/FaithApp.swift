import SwiftUI
import SwiftData

@main
struct FaithApp: App {
    @StateObject private var session: SessionStore
    @StateObject private var canon = CanonStore.shared
    @State private var dailyPassage = DailyPassageStore()

    init() {
        let context = PersistenceContainer.shared.mainContext
        _session = StateObject(wrappedValue: SessionStore(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .environmentObject(canon)
                .environment(dailyPassage)
                .task {
                    seedIfRequested()
                    canon.load()
                    Task.detached(priority: .utility) {
                        await EmbeddingIndex.shared.buildIfNeeded()
                    }
                }
        }
        .modelContainer(PersistenceContainer.shared)
    }

    @MainActor
    private func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--seed") else { return }
        let context = PersistenceContainer.shared.mainContext
        let existing = (try? context.fetch(FetchDescriptor<DayCompletion>())) ?? []
        for day in existing { context.delete(day) }
        let calendar = Calendar.current
        let offsets = [0, 1, 2, 3, 5, 7, 8, 10, 14]
        for offset in offsets {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            let day = DayCompletion(date: date)
            day.meditationDone = true
            day.morningPrayerDone = true
            day.storyReadDone = true
            day.gratitudeDone = true
            day.eveningReflectionDone = true
            context.insert(day)
        }
        try? context.save()
        ProgressStore(context: context).pushToWidget()
    }
}
