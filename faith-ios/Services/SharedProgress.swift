import Foundation
import WidgetKit

enum SharedProgress {
    static let appGroupID = "group.minh.faith-ios"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    enum Key {
        static let progress = "todayProgress"
        static let streak = "currentStreak"
        static let palette = "palette"
        static let appearance = "appearance"
    }

    static func write(progress: Double, streak: Int) {
        defaults.set(progress, forKey: Key.progress)
        defaults.set(streak, forKey: Key.streak)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func writeAppearance(palette: String, appearance: String) {
        defaults.set(palette, forKey: Key.palette)
        defaults.set(appearance, forKey: Key.appearance)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
