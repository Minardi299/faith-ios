import Foundation
import SwiftData

@Model
final class Anniversary {
    var day: Int
    var month: Int
    var year: Int
    var label: String
    var traditionRaw: String?
    var repeatsYearly: Bool
    var createdAt: Date

    init(day: Int,
         month: Int,
         year: Int,
         label: String,
         traditionRaw: String? = nil,
         repeatsYearly: Bool = true,
         createdAt: Date = .now) {
        self.day = day
        self.month = month
        self.year = year
        self.label = label
        self.traditionRaw = traditionRaw
        self.repeatsYearly = repeatsYearly
        self.createdAt = createdAt
    }

    var tradition: Tradition? {
        traditionRaw.flatMap(Tradition.init(rawValue:))
    }

    /// Does this anniversary fall on the given (day, month, year)?
    func matches(day d: Int, month m: Int, year y: Int) -> Bool {
        guard d == day, m == month else { return false }
        return repeatsYearly ? true : y == year
    }
}
