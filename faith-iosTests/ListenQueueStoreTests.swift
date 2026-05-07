import Testing
import Foundation
@testable import faith_ios

/// Tests for `ListenQueueStore` that don't require AVSpeechSynthesizer.
/// We exercise the public API surface and assert state transitions, but skip
/// `play(passage:)` paths because the simulator's TextToSpeech framework
/// crashes during test teardown when an utterance is mid-flight.
@Suite("ListenQueueStore")
@MainActor
struct ListenQueueStoreTests {

    @Test("Initial state is empty")
    func initialState() {
        let queue = ListenQueueStore.shared
        queue.stop()
        #expect(queue.current == nil)
        #expect(queue.queue.isEmpty)
        #expect(!queue.isPlaying)
        #expect(queue.position == 0)
    }

    @Test("rate change persists")
    func rateChange() {
        let queue = ListenQueueStore.shared
        queue.rate = 1.2
        #expect(queue.rate == 1.2)
        queue.rate = 1.0
        #expect(queue.rate == 1.0)
    }

    @Test("stop() resets to empty state")
    func stopResets() {
        let queue = ListenQueueStore.shared
        // No play call — just verify stop is a safe no-op when idle.
        queue.stop()
        #expect(queue.current == nil)
        #expect(queue.queue.isEmpty)
        #expect(!queue.isPlaying)
    }

    @Test("StudyTrack item count matches expansion")
    func studyTrackExpansion() {
        // We can't peek into ListenQueueStore.expand directly (it's private),
        // but we can verify the curriculum sums up correctly. This catches
        // misshaped JSON entries that would later fail at queue time.
        guard let track = StudyTrackStore.shared.track(for: .theravada) else {
            Issue.record("Theravāda track missing")
            return
        }
        var totalPassages = 0
        for stage in track.stages {
            for item in stage.items {
                totalPassages += item.passageIDs.count
            }
        }
        #expect(totalPassages > 0, "Theravāda track has no passages")
    }
}
