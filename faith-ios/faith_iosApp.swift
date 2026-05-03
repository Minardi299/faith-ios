import SwiftUI
import SwiftData

@main
struct faith_iosApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DayCompletion.self,
            ChatMessage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { seedIfRequested() }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--seed") else { return }
        let context = sharedModelContainer.mainContext
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
