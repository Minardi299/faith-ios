import Testing
import Foundation
@testable import faith_ios

@Suite("RetrievalOnlyRuntime")
@MainActor
struct RetrievalOnlyRuntimeTests {

    @Test("anger query returns at least one .citation segment")
    func angerReturnsCitation() async {
        // Prime the corpus + index.
        _ = CanonStore.shared
        await EmbeddingIndex.shared.buildIfNeeded()

        let runtime = RetrievalOnlyRuntime()
        let segs = await runtime.reply(to: "how do I sit with anger?",
                                       tradition: .theravada,
                                       history: [])
        let citationCount = segs.reduce(0) { acc, seg in
            if case .citation = seg { return acc + 1 } else { return acc }
        }
        #expect(citationCount >= 1, "Expected ≥1 citation, got \(citationCount). Segments: \(segs)")
    }

    @Test("Empty / nonsense prompt returns at least one segment without crashing")
    func gracefulNonsense() async {
        let runtime = RetrievalOnlyRuntime()
        let segs = await runtime.reply(to: "qwx zzqp nnnn",
                                       tradition: .zen,
                                       history: [])
        #expect(!segs.isEmpty)
    }
}
