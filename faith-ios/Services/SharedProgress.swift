import Foundation
import WidgetKit

enum SharedProgress {
    static let appGroupID = "group.com.faith.app"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    enum Key {
        static let progress = "todayProgress"
        static let streak = "currentStreak"
        static let palette = "palette"
        static let appearance = "appearance"
        static let passageID = "dailyPassageID"
        static let passageCode = "dailyPassageCode"
        static let passageTitle = "dailyPassageTitle"
        static let passageSnippet = "dailyPassageSnippet"
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

    static func writePassage(id: String, code: String, title: String, snippet: String) {
        defaults.set(id, forKey: Key.passageID)
        defaults.set(code, forKey: Key.passageCode)
        defaults.set(title, forKey: Key.passageTitle)
        defaults.set(snippet, forKey: Key.passageSnippet)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
