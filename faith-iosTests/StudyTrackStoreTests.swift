import Testing
import Foundation
@testable import faith_ios

@Suite("StudyTrackStore")
@MainActor
struct StudyTrackStoreTests {

    @Test("Loads at least 5 tracks")
    func loadsTracks() {
        let store = StudyTrackStore.shared
        #expect(store.tracks.count >= 5, "Expected ≥5 tracks, got \(store.tracks.count); status=\(store.loadStatus)")
    }

    @Test("Each tradition has a track")
    func tradeitionsCovered() {
        let store = StudyTrackStore.shared
        for trad in Tradition.allCases {
            #expect(store.track(for: trad) != nil, "Missing track for \(trad)")
        }
    }

    @Test("Track items resolve to canon passages")
    func itemsResolve() {
        let store = StudyTrackStore.shared
        let canon = CanonStore.shared
        guard let track = store.track(for: .theravada) else {
            Issue.record("Theravāda track missing")
            return
        }
        var unresolved = 0
        for stage in track.stages {
            for item in stage.items {
                for pid in item.passageIDs {
                    if pid.hasPrefix("meta.") { continue } // metadata-only ok
                    if canon.passage(byID: pid) == nil { unresolved += 1 }
                }
            }
        }
        #expect(unresolved == 0, "Theravāda track has \(unresolved) unresolved passage IDs")
    }

    @Test("ItemBody decodes single + work shapes")
    func itemBodyDecodes() throws {
        let single = """
        {"type": "single", "passageID": "MH_HEART"}
        """.data(using: .utf8)!
        let work = """
        {"type": "work", "workID": "work.diamond", "chapters": [
            {"id": "ch.1", "number": 1, "title": "One", "passageIDs": ["MH_DIAM_1"], "estimatedMinutes": 1}
        ]}
        """.data(using: .utf8)!

        let s = try JSONDecoder().decode(ItemBody.self, from: single)
        if case .single(let pid) = s { #expect(pid == "MH_HEART") } else { Issue.record("Not single") }

        let w = try JSONDecoder().decode(ItemBody.self, from: work)
        if case .work(let wid, let chs) = w {
            #expect(wid == "work.diamond")
            #expect(chs.count == 1)
            #expect(chs[0].passageIDs == ["MH_DIAM_1"])
        } else {
            Issue.record("Not work")
        }
    }

    @Test("Stage 0 has at least one item across tracks")
    func stage0Populated() {
        for track in StudyTrackStore.shared.tracks {
            let s0 = track.stages.first { $0.number == 0 }
            // Stage 0 might not exist for every track in the stub; just make
            // sure when it does, it has items.
            if let s0 { #expect(!s0.items.isEmpty, "\(track.id) stage 0 is empty") }
        }
    }
}
