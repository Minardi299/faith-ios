import Foundation
import SwiftData

@Model
final class PracticeRecord {
    /// Day-anchor: midnight of the practice day in the user's calendar.
    var day: Date
    var kindRaw: String        // "sit" | "read"
    var minutes: Int

    init(day: Date, kindRaw: String, minutes: Int) {
        self.day = Calendar.current.startOfDay(for: day)
        self.kindRaw = kindRaw
        self.minutes = minutes
    }

    enum Kind: String { case sit, read }

    var kind: Kind { Kind(rawValue: kindRaw) ?? .sit }
}
