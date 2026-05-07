import Foundation

/// LLMRuntime fallback that returns retrieved passages **with verbatim
/// quotes** but no model-generated prose. Used on devices where Apple's
/// Foundation Models framework is unavailable (notably the iOS Simulator)
/// and as the safe path when the real runtime errors out.
///
/// Honours the project's "never paraphrase scripture" rule — the only
/// English here is a single framing sentence. The actual scripture comes
/// directly from `CanonStore` via `CanonQuoteExtractor`.
@MainActor
final class RetrievalOnlyRuntime: LLMRuntime {

    func reply(to prompt: String,
               tradition: Tradition,
               history: [ChatMessage]) async -> [MessageSegment] {
        let index = EmbeddingIndex.shared
        await index.buildIfNeeded()
        let canon = CanonStore.shared

        let expandedQuery = Self.expand(prompt)
        let hits = index.topK(query: expandedQuery, k: 3)
        let passages: [SuttaPassage] = hits.compactMap { canon.passage(byID: $0.passageID) }

        guard !passages.isEmpty else {
            return [.text("I couldn't find anything in the canon that speaks to that. Try rephrasing — for example, 'how do I sit with anger?' or 'what does the Buddha say about grief?'")]
        }

        var segments: [MessageSegment] = [.text("From the canon: ")]
        for passage in passages {
            let quote = CanonQuoteExtractor.quote(from: passage, query: prompt)
            let cite = SuttaCite(
                code: passage.code,
                englishTitle: passage.englishTitle,
                suttaID: passage.id
            )
            if !quote.isEmpty {
                segments.append(.italic("\u{201C}" + quote + "\u{201D}"))
                segments.append(.text(" "))
            }
            segments.append(.citation(cite))
            segments.append(.text(" "))
        }
        return segments
    }

    /// Augment short colloquial queries with the canonical synonyms the canon
    /// actually uses. NLEmbedding's English word vectors don't naturally
    /// cluster "lust" with "rāga" / "kāmacchanda" / "taṇhā", so retrieval
    /// misses unless the query carries those terms itself.
    private static let synonyms: [(trigger: String, expansion: String)] = [
        ("lust", "lust sensuality desire passion craving sensual rāga kāmacchanda taṇhā"),
        ("sex", "sex sensuality lust desire passion sensual pleasure"),
        ("desire", "desire craving thirst clinging passion"),
        ("anger", "anger hatred ill-will aversion patience irritation"),
        ("hate", "hatred anger aversion ill-will"),
        ("anxiety", "anxiety fear worry restlessness agitation"),
        ("fear", "fear anxiety dread terror"),
        ("death", "death dying impermanence mortality passing away"),
        ("grief", "grief loss sorrow mourning sadness"),
        ("love", "loving-kindness mettā compassion friendliness"),
        ("kindness", "loving-kindness mettā compassion friendliness"),
        ("rebirth", "rebirth becoming saṃsāra cycle existence"),
        ("emptiness", "emptiness śūnyatā form void no-self"),
        ("self", "self non-self anatta soul identity"),
        ("mind", "mind consciousness awareness citta"),
        ("breath", "breath breathing ānāpānasati mindfulness"),
        ("meditation", "meditation jhāna concentration samādhi mindfulness"),
        ("compassion", "compassion karuṇā loving-kindness mettā"),
        ("suffering", "suffering dukkha pain dissatisfaction"),
    ]

    static func expand(_ query: String) -> String {
        let lower = query.lowercased()
        var extras: [String] = []
        for (trigger, expansion) in synonyms where lower.contains(trigger) {
            extras.append(expansion)
        }
        return extras.isEmpty ? query : query + " " + extras.joined(separator: " ")
    }
}
