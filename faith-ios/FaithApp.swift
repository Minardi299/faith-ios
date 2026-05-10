import SwiftUI
import SwiftData
import UIKit
import UserNotifications

@main
struct FaithApp: App {
    @StateObject private var session: SessionStore
    @StateObject private var canon = CanonStore.shared
    @State private var dailyPassage = DailyPassageStore()

    init() {
        let context = PersistenceContainer.shared.mainContext
        _session = StateObject(wrappedValue: SessionStore(modelContext: context))
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
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

// MARK: - NotificationDelegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    @MainActor static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the banner even when app is in foreground.
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let s = response.notification.request.content.userInfo["deeplink"] as? String,
           let url = URL(string: s) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
        completionHandler()
    }
}
