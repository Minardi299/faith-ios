import Foundation

/// A curated *reading sequence* — not a multi-day plan with audio/sit/reflect.
/// Just an ordered list of canon entries with a short note for each.
struct ReadingPathway: Identifiable, Hashable, Codable {
    let id: String
    let tradition: Tradition
    let title: String
    let subtitle: String
    let blurb: String
    let steps: [PathwayStep]

    var stepCount: Int { steps.count }
}

struct PathwayStep: Hashable, Codable {
    let suttaID: String
    let note: String
}
