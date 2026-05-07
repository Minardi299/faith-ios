import Foundation

struct Reflection: Identifiable, Hashable, Codable {
    let id: UUID
    let date: Date
    let verse: SuttaVerse
    var practiced: PracticeMark?
    var sitMinutes: Int?
    var note: String?
}

struct SuttaVerse: Hashable, Codable {
    let citation: String      // "Dhammapada 5 — Yamakavagga"
    let lines: [String]       // 3 lines, weighted roman → italic → smaller
    let suttaID: String
}

enum PracticeMark: String, Codable, Hashable {
    case yes
    case notYet
}

struct DailyJournalEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let date: Date
    var text: String
    var traditionRaw: String
}
