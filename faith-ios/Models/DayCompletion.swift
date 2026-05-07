import Foundation
import SwiftData

@Model
final class DayCompletion {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var meditationDone: Bool = false
    var morningPrayerDone: Bool = false
    var storyReadDone: Bool = false
    var gratitudeDone: Bool = false
    var eveningReflectionDone: Bool = false

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.dayKey = DayCompletion.key(for: date)
    }

    var taskFlags: [Bool] {
        [meditationDone, morningPrayerDone, storyReadDone, gratitudeDone, eveningReflectionDone]
    }

    var doneCount: Int { taskFlags.filter { $0 }.count }

    var totalCount: Int { taskFlags.count }

    var isComplete: Bool { doneCount == totalCount }

    var progress: Double { Double(doneCount) / Double(totalCount) }

    static func key(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let f = DateFormatter()
        f.calendar = .init(identifier: .gregorian)
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: day)
    }
}
