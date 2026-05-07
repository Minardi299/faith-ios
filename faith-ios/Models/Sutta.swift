import Foundation

/// How long an entry takes to read at a glance.
/// `short` ≈ < 1 min · `medium` 1–7 min · `long` 7–25 min · `book` 25+ min.
enum LengthTier: String, Codable, Hashable {
    case short, medium, long, book

    var label: String {
        switch self {
        case .short:  "short"
        case .medium: "medium"
        case .long:   "long"
        case .book:   "book"
        }
    }
}

/// What kind of passage this is. Drives icon, narrator framing, and where the
/// item slots into the curriculum. Default `.sutra` keeps existing canon.json
/// loading unchanged.
enum PassageKind: String, Codable, Hashable {
    case sutra          // canonical scripture (default)
    case saying         // master sayings (Linji, Hakuin, Layman Pang)
    case verse          // Dhammapada, songs of Milarepa, gāthā collections
    case koan           // Mumonkan / Blue Cliff cases
    case commentary     // śāstra, treatises, abhidharma
    case story          // foundational narrative — sourced from PD compilations
    case introduction   // Stage 0 master orientation — sourced from PD intro material
}

/// Provenance for a passage body. Required for any non-canon entry so we can
/// audit licensing later.
struct PassageAttribution: Hashable, Codable {
    let translator: String?
    let sourceURL: String?
    let license: String?       // e.g. "PD", "CC0", "CC-BY-SA-3.0"
    let fetchedAt: Date?

    init(translator: String? = nil,
         sourceURL: String? = nil,
         license: String? = nil,
         fetchedAt: Date? = nil) {
        self.translator = translator
        self.sourceURL = sourceURL
        self.license = license
        self.fetchedAt = fetchedAt
    }
}

struct SuttaPassage: Identifiable, Hashable, Codable {
    let id: String          // canonical cite ID, e.g. "MN21"
    let code: String        // "MN 21"
    let title: String       // "Kakacūpama Sutta"
    let englishTitle: String // "Simile of the Saw"
    let tradition: Tradition
    let collection: String      // display name, e.g. "Majjhima Nikāya"
    let collectionID: String    // joins with CanonCollection.id, e.g. "mn"
    let lines: [SuttaLine]
    /// Marks an entry whose canonical text is not yet bundled in this preview pack.
    let isStub: Bool
    /// Word count of the body text (computed at build time).
    let wordCount: Int
    /// Estimated reading minutes at ~220 wpm contemplative pace.
    let readingMinutes: Int
    /// Coarse length classification for badges + filtering.
    let lengthTier: LengthTier
    /// Free-form tags. Known: `core` (cross-tradition foundation), `intro`,
    /// `verse`, `koan`, `lojong`, `practice`.
    let tags: [String]
    /// What kind of passage this is. Drives icon + narrator framing.
    let kind: PassageKind
    /// Voice attribution for stories / introductions. nil for canon.
    let narrator: String?
    /// Optional pre-segmented script with breath/pause markers. When nil, the
    /// audio source joins `lines` as a single utterance.
    let audioScript: [String]?
    /// Provenance for non-canon entries. nil for canon.
    let attribution: PassageAttribution?

    init(id: String,
         code: String,
         title: String,
         englishTitle: String,
         tradition: Tradition,
         collection: String,
         collectionID: String,
         lines: [SuttaLine],
         isStub: Bool = false,
         wordCount: Int = 0,
         readingMinutes: Int = 1,
         lengthTier: LengthTier = .short,
         tags: [String] = [],
         kind: PassageKind = .sutra,
         narrator: String? = nil,
         audioScript: [String]? = nil,
         attribution: PassageAttribution? = nil) {
        self.id = id
        self.code = code
        self.title = title
        self.englishTitle = englishTitle
        self.tradition = tradition
        self.collection = collection
        self.collectionID = collectionID
        self.lines = lines
        self.isStub = isStub
        self.wordCount = wordCount
        self.readingMinutes = readingMinutes
        self.lengthTier = lengthTier
        self.tags = tags
        self.kind = kind
        self.narrator = narrator
        self.audioScript = audioScript
        self.attribution = attribution
    }

    var displayCode: String { "\(code) · \(englishTitle)" }

    /// Compact reading-time badge text: "<1 min", "5 min", "22 min", "book".
    var readingBadge: String {
        switch lengthTier {
        case .short:  return "< 1 min"
        case .book:   return "book"
        default:      return "\(readingMinutes) min"
        }
    }

    var isCore: Bool { tags.contains("core") }

    /// True for entries whose body has not been sourced; we ship metadata only.
    var isMetadataOnly: Bool { lines.isEmpty && !isStub }

    enum CodingKeys: String, CodingKey {
        case id, code, title, englishTitle, tradition, collection, collectionID, lines, isStub
        case wordCount, readingMinutes, lengthTier, tags
        case kind, narrator, audioScript, attribution
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id             = try c.decode(String.self, forKey: .id)
        self.code           = try c.decode(String.self, forKey: .code)
        self.title          = try c.decode(String.self, forKey: .title)
        self.englishTitle   = try c.decode(String.self, forKey: .englishTitle)
        self.tradition      = try c.decode(Tradition.self, forKey: .tradition)
        self.collection     = try c.decode(String.self, forKey: .collection)
        self.collectionID   = try c.decode(String.self, forKey: .collectionID)
        self.lines          = try c.decode([SuttaLine].self, forKey: .lines)
        self.isStub         = try c.decodeIfPresent(Bool.self, forKey: .isStub) ?? false
        self.wordCount      = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        self.readingMinutes = try c.decodeIfPresent(Int.self, forKey: .readingMinutes) ?? 1
        self.lengthTier     = try c.decodeIfPresent(LengthTier.self, forKey: .lengthTier) ?? .short
        self.tags           = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.kind           = try c.decodeIfPresent(PassageKind.self, forKey: .kind) ?? .sutra
        self.narrator       = try c.decodeIfPresent(String.self, forKey: .narrator)
        self.audioScript    = try c.decodeIfPresent([String].self, forKey: .audioScript)
        self.attribution    = try c.decodeIfPresent(PassageAttribution.self, forKey: .attribution)
    }
}

struct SuttaLine: Hashable, Codable {
    let number: Int?
    let text: String
    /// Italicized Pāli/Sanskrit/Tibetan terms with optional gloss.
    let glossTerms: [GlossTerm]

    init(number: Int? = nil, text: String, glossTerms: [GlossTerm] = []) {
        self.number = number
        self.text = text
        self.glossTerms = glossTerms
    }

    enum CodingKeys: String, CodingKey { case number, text, glossTerms }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.number     = try c.decodeIfPresent(Int.self, forKey: .number)
        self.text       = try c.decode(String.self, forKey: .text)
        self.glossTerms = try c.decodeIfPresent([GlossTerm].self, forKey: .glossTerms) ?? []
    }
}

struct GlossTerm: Hashable, Codable {
    let term: String
    let gloss: String
}

struct CanonCollection: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let count: Int
}

struct CanonDivision: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let collections: [CanonCollection]
}
