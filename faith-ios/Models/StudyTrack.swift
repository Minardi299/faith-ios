import Foundation

/// Top-level curriculum unit: one tradition's full reading path, novice → advanced.
struct StudyTrack: Identifiable, Hashable, Codable {
    let id: String           // "track.zen"
    let tradition: Tradition
    let name: String         // "Zen / Chan / Seon"
    let subtitle: String     // "A special transmission outside the scriptures"
    let blurb: String
    let stages: [StudyStage]

    var totalItemCount: Int { stages.reduce(0) { $0 + $1.items.count } }
    var estimatedMinutes: Int { stages.reduce(0) { $0 + $1.estimatedMinutes } }
}

/// A single stage within a track. Stage 0 = orientation, ascending = deeper.
struct StudyStage: Identifiable, Hashable, Codable {
    let id: String           // "track.zen.stage.1"
    let trackID: String
    let number: Int          // 0..n
    let title: String        // "The Sūtras Behind the Silence"
    let subtitle: String
    let blurb: String
    let items: [StudyItem]

    var estimatedMinutes: Int { items.reduce(0) { $0 + $1.estimatedMinutes } }
}

/// A unit the student picks. May resolve to a single passage or a chaptered work.
struct StudyItem: Identifiable, Hashable, Codable {
    let id: String
    let stageID: String
    let trackID: String
    let kind: PassageKind     // shared with passage; drives icon + framing
    let title: String         // display title
    let subtitle: String?     // "Translated by …", "48 cases", chapter count, etc.
    let blurb: String         // master's framing, 1-2 sentences
    let estimatedMinutes: Int
    let body: ItemBody
    /// Optional out-link for ✍ metadata-only items (publisher / library).
    let acquireURL: String?

    /// True for entries that ship structurally complete but with no body text
    /// (✍ metadata-only). Listen plays the metadata blurb only.
    var isMetadataOnly: Bool {
        if case .single(let id) = body, id.hasPrefix("meta.") { return true }
        return false
    }

    /// Flattened ordered list of passage IDs used to expand a queue.
    var passageIDs: [String] {
        switch body {
        case .single(let id): return [id]
        case .work(_, let chapters): return chapters.flatMap(\.passageIDs)
        }
    }

    /// True for chaptered works that should support a chapter picker.
    var hasChapters: Bool {
        if case .work = body { return true }
        return false
    }
}

/// A chaptered work (Shōbōgenzō, Mumonkan, Diamond, Lamrim Chenmo, etc.)
/// composed of ordered chapters that each map to one or more canon passages.
struct WorkChapter: Identifiable, Hashable, Codable {
    let id: String           // "ch.diamond.10"
    let number: Int          // 1-based for display
    let title: String        // "Abide Nowhere"
    let passageIDs: [String]
    let estimatedMinutes: Int
}

/// The shape of an item's body. Tagged-union JSON: `{ "type": "single", ... }`
/// or `{ "type": "work", ... }`.
enum ItemBody: Hashable, Codable {
    case single(passageID: String)
    case work(workID: String, chapters: [WorkChapter])

    private enum CodingKeys: String, CodingKey {
        case type, passageID, workID, chapters
    }

    enum BodyType: String, Codable { case single, work }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(BodyType.self, forKey: .type)
        switch type {
        case .single:
            let id = try c.decode(String.self, forKey: .passageID)
            self = .single(passageID: id)
        case .work:
            let workID = try c.decode(String.self, forKey: .workID)
            let chapters = try c.decode([WorkChapter].self, forKey: .chapters)
            self = .work(workID: workID, chapters: chapters)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .single(let id):
            try c.encode(BodyType.single, forKey: .type)
            try c.encode(id, forKey: .passageID)
        case .work(let workID, let chapters):
            try c.encode(BodyType.work, forKey: .type)
            try c.encode(workID, forKey: .workID)
            try c.encode(chapters, forKey: .chapters)
        }
    }
}
