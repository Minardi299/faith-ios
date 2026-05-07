import Foundation

/// UI-level seed data: reading list, presets, calendar observances, daily verse.
/// The actual canonical text lives in CanonStore (loaded from canon.json).
enum SeedContent {

    // MARK: - Library hierarchy (matches the IDs/counts in CanonStore)

    static let library: [Tradition: [CanonDivision]] = [
        .theravada: [
            CanonDivision(id: "sutta", name: "Sutta Piṭaka", subtitle: "The Basket of Discourses", collections: [
                .init(id: "dn",  name: "Dīgha Nikāya",     subtitle: "Long Discourses",     count: 34),
                .init(id: "mn",  name: "Majjhima Nikāya",  subtitle: "Middle-Length",       count: 152),
                .init(id: "sn",  name: "Saṃyutta Nikāya",  subtitle: "Connected",           count: 1819),
                .init(id: "an",  name: "Aṅguttara Nikāya", subtitle: "Numerical",           count: 1408)
            ]),
            CanonDivision(id: "kn", name: "Khuddaka Nikāya", subtitle: "The Minor Collection", collections: [
                .init(id: "dhp",  name: "Dhammapada",          subtitle: "Verses on the Dhamma",        count: 26),
                .init(id: "snp",  name: "Sutta Nipāta",        subtitle: "Group of Discourses",         count: 73),
                .init(id: "iti",  name: "Itivuttaka",          subtitle: "Sayings of the Buddha",       count: 112),
                .init(id: "ud",   name: "Udāna",               subtitle: "Inspired Utterances",         count: 80),
                .init(id: "thag", name: "Theragāthā",          subtitle: "Verses of the Elder Monks",   count: 264),
                .init(id: "thig", name: "Therīgāthā",          subtitle: "Verses of the Elder Nuns",    count: 73),
                .init(id: "kp",   name: "Khuddakapāṭha",       subtitle: "Short Readings",              count: 9),
                .init(id: "ja",   name: "Jātaka",              subtitle: "Birth Stories",               count: 547),
                .init(id: "cp",   name: "Cariyāpiṭaka",        subtitle: "Basket of Conduct",           count: 35)
            ])
        ],
        .mahayana: [
            CanonDivision(id: "prajna", name: "Prajñāpāramitā", subtitle: "Perfection of Wisdom", collections: [
                .init(id: "heart",   name: "Heart Sūtra",   subtitle: "Prajñāpāramitā Hṛdaya", count: 1),
                .init(id: "diamond", name: "Diamond Sūtra", subtitle: "Vajracchedikā",         count: 32)
            ]),
            CanonDivision(id: "lotus", name: "Lotus & Pure Land", subtitle: "Devotional Sūtras", collections: [
                .init(id: "lotus",  name: "Lotus Sūtra",      subtitle: "Saddharma-puṇḍarīka", count: 28),
                .init(id: "larger", name: "Larger Sukhāvatī", subtitle: "Amitābha's Pure Land", count: 1)
            ])
        ],
        .vajrayana: [
            CanonDivision(id: "lojong", name: "Lojong & Lamrim", subtitle: "Mind-training texts", collections: [
                .init(id: "37",     name: "Thirty-Seven Practices", subtitle: "Tokmé Zangpo", count: 37),
                .init(id: "lamrim", name: "Lamrim Chenmo",          subtitle: "Tsongkhapa", count: 24)
            ])
        ],
        .zen: [
            CanonDivision(id: "koan", name: "Kōan Collections", subtitle: "For sitting and inquiry", collections: [
                .init(id: "gateless", name: "Mumonkan",         subtitle: "The Gateless Gate", count: 48),
                .init(id: "blue",     name: "Blue Cliff Record", subtitle: "Hekiganroku",     count: 100)
            ]),
            CanonDivision(id: "core", name: "Core Texts", subtitle: "Voices of the patriarchs", collections: [
                .init(id: "platf", name: "Platform Sūtra", subtitle: "Huineng", count: 10),
                .init(id: "heart", name: "Heart Sūtra",    subtitle: "Maka Hannya Haramita", count: 1)
            ])
        ],
        .secular: [
            CanonDivision(id: "core", name: "Foundations", subtitle: "Universal teachings", collections: [
                .init(id: "dhp",  name: "Dhammapada",         subtitle: "Verses on the Dhamma",  count: 26),
                .init(id: "snp",  name: "Sutta Nipāta",       subtitle: "Includes Mettā Sutta", count: 73),
                .init(id: "ud",   name: "Udāna",              subtitle: "Inspired Utterances",  count: 80)
            ])
        ]
    ]

    // MARK: - Reading list (sample state)

    struct ReadingItem: Identifiable, Hashable {
        let id = UUID()
        let suttaID: String
        let tradition: Tradition
        let title: String
        let progress: Double
        let lastSeen: String
        let lastLine: String
    }

    static let continueReading = ReadingItem(
        suttaID: "mn10",
        tradition: .theravada,
        title: "Satipaṭṭhāna Sutta · Mindfulness Meditation",
        progress: 0.34,
        lastSeen: "2 hours ago",
        lastLine: "Breathing in long, he discerns: \u{201C}I am breathing in long.\u{201D}"
    )

    static let currentlyReading: [ReadingItem] = [
        .init(suttaID: "dhp1-20",     tradition: .theravada, title: "Dhammapada · 1. Pairs",                    progress: 0.62, lastSeen: "yesterday",  lastLine: ""),
        .init(suttaID: "ZEN_MUMON_1", tradition: .zen,       title: "Mumonkan · Joshu's Mu",                    progress: 0.18, lastSeen: "3 days ago", lastLine: ""),
        .init(suttaID: "MH_HEART",    tradition: .mahayana,  title: "Heart Sūtra · The mantra",                 progress: 0.88, lastSeen: "last week",   lastLine: "")
    ]

    static let finishedBooks: [(String, String, Tradition, String)] = [
        ("Karaṇīya Mettā Sutta",  "Mar 12", .theravada, "snp1.8"),
        ("Bhāra Sutta",           "Feb 19", .theravada, "sn22.22"),
        ("Heart Sūtra",           "Jan 30", .zen,       "MH_HEART"),
        ("Dhammapada · Pairs",    "Jan 12", .secular,   "dhp1-20")
    ]

    static let wantToRead: [(String, String, Tradition, String)] = [
        ("Dīgha Nikāya · Mahāparinibbāna", "Long Discourses",      .theravada, "dn16"),
        ("Lotus Sūtra · Skillful Means",   "Saddharma-puṇḍarīka",  .mahayana,  "MH_LOTUS_2"),
        ("37 Practices",                    "Tokmé Zangpo",         .vajrayana, "VJ_37_1"),
        ("Mumonkan · Hyakujō's Fox",       "The Gateless Gate",    .zen,       "ZEN_MUMON_2")
    ]

    static let presetPlans: [(title: String, blurb: String, length: Int)] = [
        ("Walking with Grief", "A 14-day path through teachings on impermanence and the loss of those we love.", 14),
        ("Beginning Mind", "Seven days of foundational practice — breath, posture, the first instructions.", 7),
        ("Form is Emptiness", "Thirty days through the Heart Sūtra and core Mahāyāna teachings on śūnyatā.", 30),
        ("30 Days in the Pāli Canon", "A month of suttas: the Buddha's voice in the early texts.", 30)
    ]

    // MARK: - Daily verse

    static let dailyVerse = SuttaVerse(
        citation: "Dhammapada · 1. Pairs",
        lines: [
            "For never is hatred laid to rest by hate, ",
            "it’s only laid to rest by love —",
            "this is an eternal truth."
        ],
        suttaID: "dhp1-20"
    )

    // MARK: - Calendar (Nov 2026 — focal month from design)

    static let observances: [HolyDay] = [
        .init(id: UUID(), day: 1,  month: 11, year: 2026, kind: .uposatha,   label: "Last-Quarter Uposatha", subtitle: nil, traditionRaw: "theravada"),
        .init(id: UUID(), day: 9,  month: 11, year: 2026, kind: .uposatha,   label: "New Moon Uposatha",     subtitle: nil, traditionRaw: "theravada"),
        .init(id: UUID(), day: 16, month: 11, year: 2026, kind: .uposatha,   label: "First-Quarter Uposatha", subtitle: nil, traditionRaw: "theravada"),
        .init(id: UUID(), day: 17, month: 11, year: 2026, kind: .memorial,   label: "Patriarch Linji's Death", subtitle: nil, traditionRaw: "zen"),
        .init(id: UUID(), day: 22, month: 11, year: 2026, kind: .memorial,   label: "Bodhidharma's Memorial", subtitle: nil, traditionRaw: "zen"),
        .init(id: UUID(), day: 24, month: 11, year: 2026, kind: .major,      label: "Anāpānasati Day", subtitle: "The Buddha praises mindfulness of breathing", traditionRaw: "theravada"),
        .init(id: UUID(), day: 25, month: 11, year: 2026, kind: .observance, label: "Kaṭhina ends",  subtitle: nil, traditionRaw: "theravada"),
        .init(id: UUID(), day: 28, month: 11, year: 2026, kind: .memorial,   label: "Tsongkhapa's Birth", subtitle: nil, traditionRaw: "vajrayana"),
        .init(id: UUID(), day: 6,  month: 11, year: 2026, kind: .personal,   label: "Father — 7 years", subtitle: nil, traditionRaw: nil),
        .init(id: UUID(), day: 19, month: 11, year: 2026, kind: .personal,   label: "First sit", subtitle: nil, traditionRaw: nil),
    ]

    static let lunar2026Nov: [Int: LunarPhase] = [
        1: .lastQuarter, 9: .newMoon, 16: .firstQuarter, 24: .fullMoon
    ]

    /// 0 = nothing, 1 = sit, 2 = read, 3 = both
    static let practice2026Nov: [Int: Int] = [
        1: 3, 2: 3, 3: 1, 4: 0, 5: 3, 6: 3, 7: 2, 8: 3,
        9: 3, 10: 3, 11: 3, 12: 1, 13: 3, 14: 3, 15: 0, 16: 3,
        17: 2, 18: 3, 19: 3, 20: 3, 21: 1, 22: 3, 23: 3
    ]

    // MARK: - Lookup convenience

    @MainActor
    static func sutta(byID id: String) -> SuttaPassage? {
        CanonStore.shared.passage(byID: id)
    }
}
