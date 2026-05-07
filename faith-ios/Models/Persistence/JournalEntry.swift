import Foundation
import SwiftData

@Model
final class JournalEntry {
    var date: Date
    var text: String
    var traditionRaw: String
    var suttaID: String?
    var planID: UUID?

    init(date: Date = .now,
         text: String,
         traditionRaw: String,
         suttaID: String? = nil,
         planID: UUID? = nil) {
        self.date = date
        self.text = text
        self.traditionRaw = traditionRaw
        self.suttaID = suttaID
        self.planID = planID
    }

    var tradition: Tradition? { Tradition(rawValue: traditionRaw) }
}
