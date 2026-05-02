import Foundation
import WidgetKit

enum SharedProgress {
    static let appGroupID = "group.minh.faith-ios"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private enum Key {
        static let progress = "todayProgress"
        static let streak = "currentStreak"
    }

    static var progress: Double {
        defaults.double(forKey: Key.progress)
    }

    static var streak: Int {
        defaults.integer(forKey: Key.streak)
    }

    static func write(progress: Double, streak: Int) {
        defaults.set(progress, forKey: Key.progress)
        defaults.set(streak, forKey: Key.streak)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
