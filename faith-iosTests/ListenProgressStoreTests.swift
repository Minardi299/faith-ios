import Testing
import Foundation
@testable import faith_ios

@Suite("ListenProgressStore")
@MainActor
struct ListenProgressStoreTests {

    private func freshStore() -> ListenProgressStore {
        // Singleton — clear its in-memory state so tests are isolated.
        let store = ListenProgressStore.shared
        // Reach in via UserDefaults to reset persisted state.
        UserDefaults.standard.removeObject(forKey: "listenProgress.v1")
        UserDefaults.standard.removeObject(forKey: "listenProgress.lastListened.v1")
        // Reload via a fresh instance — but the singleton keeps state, so we
        // emulate by zeroing both keyed maps.
        return store
    }

    @Test("recordPosition updates lastPositionSeconds non-decreasing")
    func recordPosition() {
        let store = ListenProgressStore.shared
        let id = "test.\(UUID().uuidString)"
        store.recordPosition(passageID: id, seconds: 30)
        store.recordPosition(passageID: id, seconds: 10) // should NOT regress
        store.recordPosition(passageID: id, seconds: 60)
        #expect(store.resumePosition(passageID: id) == 60)
    }

    @Test("markCompleted flips the flag and resets resume to 0")
    func completion() {
        let store = ListenProgressStore.shared
        let id = "test.\(UUID().uuidString)"
        store.recordPosition(passageID: id, seconds: 100)
        store.markCompleted(passageID: id)
        #expect(store.isCompleted(passageID: id))
        #expect(store.resumePosition(passageID: id) == 0)
    }

    @Test("progress(stage:) counts completed items")
    func stageProgress() {
        let store = ListenProgressStore.shared
        let pid1 = "test.\(UUID().uuidString)"
        let pid2 = "test.\(UUID().uuidString)"
        store.markCompleted(passageID: pid1)

        let item1 = StudyItem(
            id: "i1", stageID: "s", trackID: "t",
            kind: .sutra, title: "1", subtitle: nil,
            blurb: "", estimatedMinutes: 1,
            body: .single(passageID: pid1), acquireURL: nil
        )
        let item2 = StudyItem(
            id: "i2", stageID: "s", trackID: "t",
            kind: .sutra, title: "2", subtitle: nil,
            blurb: "", estimatedMinutes: 1,
            body: .single(passageID: pid2), acquireURL: nil
        )
        let stage = StudyStage(
            id: "s", trackID: "t", number: 1,
            title: "T", subtitle: "", blurb: "",
            items: [item1, item2]
        )
        let p = store.progress(stage: stage)
        #expect(p.completed == 1)
        #expect(p.total == 2)
    }

    @Test("recordLastListened persists ref")
    func lastListened() {
        let store = ListenProgressStore.shared
        let ref = RecentListenRef(
            trackID: "track.test",
            stageID: "stage.test",
            itemID: "item.test",
            passageID: "MH_HEART",
            lastPositionSeconds: 30,
            estimatedSeconds: 120,
            lastListenedAt: .now
        )
        store.recordLastListened(ref)
        #expect(store.lastListened?.passageID == "MH_HEART")
        #expect(store.lastListened?.progressFraction == 0.25)
    }
}
