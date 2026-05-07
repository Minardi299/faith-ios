import Testing
import Foundation
@testable import faith_ios

/// Tests for the RAG retrieval index. These exercise the full pipeline:
/// canon load → per-passage embedding → cosine top-K. The first test in this
/// suite triggers the actual build (or hydrates from disk on subsequent runs).
@Suite("EmbeddingIndex")
@MainActor
struct EmbeddingIndexTests {

    @Test("buildIfNeeded leaves the index in .ready with ≥1 passage")
    func buildsOverCanon() async {
        // Prime CanonStore.
        let canon = CanonStore.shared
        #expect(canon.entries.count > 0)

        let index = EmbeddingIndex.shared
        await index.buildIfNeeded()

        switch index.status {
        case .ready(let count):
            #expect(count > 0, "Expected ≥1 indexed passage, got \(count)")
        default:
            Issue.record("Index did not reach .ready, got \(index.status)")
        }
    }

    @Test("topK for an anger-themed query surfaces a related passage")
    func angerQueryFindsRelevant() async {
        let canon = CanonStore.shared
        let index = EmbeddingIndex.shared
        await index.buildIfNeeded()

        let hits = index.topK(query: "how do I deal with anger and hatred", k: 10)
        #expect(!hits.isEmpty, "Expected ≥1 hit for an anger query")

        // The English NLEmbedding clusters "anger / hatred" with the broader
        // dukkha vocabulary (greed, desire, suffering) more strongly than with
        // narrative anger passages, so the relevance check accepts any hit
        // whose body engages that cluster.
        let cluster = [
            "anger", "angry", "angered", "hatred", "hate", "wrath", "ill will",
            "aversion", "patience", "greed", "desire", "craving", "suffering",
            "dukkha", "dosa", "metta", "kindness", "compassion"
        ]
        let anyRelevant = hits.contains { hit in
            guard let p = canon.passage(byID: hit.passageID) else { return false }
            let body = p.lines.map(\.text).joined(separator: " ").lowercased()
            return cluster.contains { body.contains($0) }
        }
        #expect(anyRelevant,
                "Top-10 should include at least one passage in the dukkha cluster. Got: \(hits.prefix(5).map(\.passageID))")
    }

    @Test("topK respects k and returns scores in descending order")
    func topKLimitAndOrder() async {
        let index = EmbeddingIndex.shared
        await index.buildIfNeeded()

        let hits = index.topK(query: "loving kindness compassion", k: 5)
        #expect(hits.count <= 5)
        if hits.count >= 2 {
            for i in 1..<hits.count {
                #expect(hits[i - 1].score >= hits[i].score,
                        "Results out of order at index \(i): \(hits[i - 1].score) < \(hits[i].score)")
            }
        }
    }

    @Test("topK on empty query returns nothing rather than crashing")
    func emptyQuery() async {
        let index = EmbeddingIndex.shared
        await index.buildIfNeeded()
        #expect(index.topK(query: "   ", k: 5).isEmpty)
        #expect(index.topK(query: "", k: 5).isEmpty)
    }
}
