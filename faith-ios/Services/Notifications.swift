import Foundation
import UserNotifications
import os

private let log = Logger(subsystem: "com.faith.app", category: "notifications")

@MainActor
enum Notifications {
    static let dailyReminderID = "faith.dailyReminder"

    /// Returns whether notifications are authorized; requests if undetermined.
    @discardableResult
    static func requestAuthIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    /// Schedules a single daily-repeating reminder at the given hour:minute.
    /// Replaces any existing schedule for `dailyReminderID`.
    static func scheduleDailyReminder(at hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])

        let content = UNMutableNotificationContent()
        content.title = "Today's passage is here"
        content.body = "A line from the canon, waiting."
        content.sound = .default
        content.userInfo = ["deeplink": "faith://today"]

        var dc = DateComponents()
        dc.hour = hour
        dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)

        let request = UNNotificationRequest(
            identifier: dailyReminderID,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            log.error("scheduleDailyReminder failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }
}
