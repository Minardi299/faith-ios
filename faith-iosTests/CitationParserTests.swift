import Testing
import Foundation
@testable import faith_ios

@Suite("CitationParser")
@MainActor
struct CitationParserTests {

    @Test("Plain text with no citations yields a single .text segment")
    func plainText() {
        let segs = CitationParser.parse("Hello world.")
        #expect(segs.count == 1)
        if case .text(let s) = segs.first { #expect(s == "Hello world.") }
        else { Issue.record("Expected .text, got \(segs)") }
    }

    @Test("Single known citation splits into text/citation/text")
    func singleCitation() {
        // mn21 is in canon.json
        let segs = CitationParser.parse("Read [SC:mn21] for context.")
        #expect(segs.count == 3)
        guard segs.count == 3 else { return }
        if case .text(let a) = segs[0] { #expect(a == "Read ") }
        else { Issue.record("seg 0 not .text") }
        if case .citation(let cite) = segs[1] {
            #expect(cite.suttaID == "mn21")
        } else {
            Issue.record("seg 1 not .citation")
        }
        if case .text(let b) = segs[2] { #expect(b == " for context.") }
        else { Issue.record("seg 2 not .text") }
    }

    @Test("Two citations with prose between them")
    func twoCitations() {
        let segs = CitationParser.parse("First [SC:mn21] then [SC:MH_HEART] done.")
        #expect(segs.count == 5)
        var citationCount = 0
        for s in segs { if case .citation = s { citationCount += 1 } }
        #expect(citationCount == 2)
    }

    @Test("Unknown id is preserved as literal text")
    func unknownId() {
        let segs = CitationParser.parse("Try [SC:does-not-exist] sometime.")
        // The unknown token stays as text. So we expect 1 single concatenated
        // text segment OR text/text/text — both shapes are acceptable, what
        // matters is no .citation appears and the literal token is present.
        let joined = segs.map { seg -> String in
            switch seg {
            case .text(let s): return s
            case .italic(let s): return s
            case .citation(let c): return "[\(c.suttaID)]"
            }
        }.joined()
        #expect(joined.contains("[SC:does-not-exist]"))
        let hasCitation = segs.contains { if case .citation = $0 { return true } else { return false } }
        #expect(!hasCitation)
    }

    @Test("Empty input returns empty array")
    func emptyInput() {
        #expect(CitationParser.parse("").isEmpty)
    }
}
