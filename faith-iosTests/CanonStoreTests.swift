import Testing
import Foundation
@testable import faith_ios

@Suite("CanonStore")
@MainActor
struct CanonStoreTests {

    @Test("Loads at least 4000 entries")
    func loadsCanon() {
        let store = CanonStore.shared
        let count = store.entries.count
        #expect(count > 4000, "Expected ≥4000 canon entries, got \(count); status=\(store.loadStatus)")
    }

    @Test("MN 21 looks up via real bilara id")
    func mn21Lookup() {
        guard let p = CanonStore.shared.passage(byID: "mn21") else {
            Issue.record("MN 21 (mn21) not found")
            return
        }
        #expect(p.tradition == .theravada)
        #expect(p.code.lowercased().contains("mn"))
    }

    @Test("Heart Sutra (curated) looks up")
    func heartSutraLookup() {
        let p = CanonStore.shared.passage(byID: "MH_HEART")
        #expect(p != nil)
        #expect(p?.tradition == .mahayana)
    }

    @Test("Mumonkan 1 (curated) looks up")
    func mumon1Lookup() {
        let p = CanonStore.shared.passage(byID: "ZEN_MUMON_1")
        #expect(p != nil)
        #expect(p?.tradition == .zen)
    }

    @Test("search('heart') returns Heart Sūtra entries")
    func searchHeart() {
        let hits = CanonStore.shared.search("heart")
        let any = hits.contains { $0.id == "MH_HEART" }
        #expect(any, "Expected the curated Heart Sūtra in 'heart' search results")
    }

    @Test("search('MN 10') finds Satipaṭṭhāna")
    func searchMN10() {
        let hits = CanonStore.shared.search("MN 10")
        let any = hits.contains { $0.id.lowercased().hasPrefix("mn10") }
        #expect(any, "Expected MN 10 in search results")
    }
}
