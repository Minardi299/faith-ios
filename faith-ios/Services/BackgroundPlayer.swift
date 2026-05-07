import Foundation
import AVFoundation
import Combine

/// Seamless looping ambient player. Uses `AVQueuePlayer` + `AVPlayerLooper`,
/// which is Apple's purpose-built primitive for gapless audio looping —
/// the next iteration is queued and starts on the same render boundary as
/// the current one ends. No stop-and-start, no perceptible seam.
@MainActor
final class BackgroundPlayer: ObservableObject {

    static let shared = BackgroundPlayer()

    @Published private(set) var currentID: String?
    @Published private(set) var isPlaying: Bool = false

    private var queuePlayer: AVQueuePlayer?
    /// Must be retained for the lifetime of playback — losing this reference
    /// would let `AVPlayerLooper` deallocate and looping would stop.
    private var looper: AVPlayerLooper?

    private init() {}

    /// Tap-to-preview semantics: tapping the same background twice toggles
    /// it off; tapping a different one switches. When the sit begins, the
    /// preview just keeps looping into the session — no audio gap.
    func play(_ background: MeditationBackground) {
        if currentID == background.id, isPlaying {
            stop()
            return
        }
        let candidates: [URL?] = [
            Bundle.main.url(forResource: background.filename, withExtension: "mp3", subdirectory: "backgrounds"),
            Bundle.main.url(forResource: background.filename, withExtension: "mp3"),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            print("⚠️ BackgroundPlayer: bundle is missing \(background.filename).mp3")
            return
        }

        teardown()

        try? AVAudioSession.sharedInstance().setCategory(.playback,
                                                         mode: .default,
                                                         options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        let qp = AVQueuePlayer()
        let lp = AVPlayerLooper(player: qp, templateItem: item)
        self.queuePlayer = qp
        self.looper = lp
        self.currentID = background.id

        qp.play()
        isPlaying = true
    }

    func stop() {
        queuePlayer?.pause()
        looper?.disableLooping()
        teardown()
        currentID = nil
        isPlaying = false
    }

    private func teardown() {
        looper = nil
        queuePlayer = nil
    }
}
