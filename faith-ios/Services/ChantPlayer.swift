import Foundation
import AVFoundation
import Combine

/// Looping chant player. Uses `AVQueuePlayer` + `AVPlayerLooper` for
/// seamless gapless looping — no stop/start at clip boundary. When `loop`
/// is false (used for in-picker preview) the chant plays once and stops.
@MainActor
final class ChantPlayer: ObservableObject {

    static let shared = ChantPlayer()

    @Published private(set) var currentID: String?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    /// Single-item player used for one-shot preview playback.
    private var previewPlayer: AVPlayer?
    private var previewTimeObserver: Any?
    private var previewEndObserver: NSObjectProtocol?

    /// Loop machinery for the active sit. Both must be retained for the
    /// lifetime of playback.
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    private init() {}

    /// Plays the chant. Defaults to `loop = true` (sit playback). Pass
    /// `loop: false` for in-picker preview — chant plays once then stops.
    /// If the audio file is missing this is a no-op.
    func play(_ chant: Chant, loop: Bool = true) {
        if currentID == chant.id, isPlaying {
            stop()
            return
        }

        let candidates: [URL?] = [
            Bundle.main.url(forResource: chant.filename, withExtension: "mp3", subdirectory: "chants"),
            Bundle.main.url(forResource: chant.filename, withExtension: "mp3"),
            Bundle.main.url(forResource: chant.filename, withExtension: "m4a", subdirectory: "chants"),
            Bundle.main.url(forResource: chant.filename, withExtension: "m4a"),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            print("⚠️ ChantPlayer: bundle is missing \(chant.filename).mp3 — run tools/build_chants.py")
            return
        }

        teardown()

        try? AVAudioSession.sharedInstance().setCategory(.playback,
                                                         mode: .spokenAudio,
                                                         options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        currentID = chant.id
        duration = TimeInterval(chant.estimatedSeconds)
        position = 0

        if loop {
            startLoopPlayback(url: url)
        } else {
            startPreviewPlayback(url: url)
        }
    }

    func stop() {
        queuePlayer?.pause()
        looper?.disableLooping()
        previewPlayer?.pause()
        teardown()
        currentID = nil
        isPlaying = false
        position = 0
        duration = 0
    }

    // MARK: - Loop playback

    private func startLoopPlayback(url: URL) {
        let item = AVPlayerItem(url: url)
        let qp = AVQueuePlayer()
        let lp = AVPlayerLooper(player: qp, templateItem: item)
        self.queuePlayer = qp
        self.looper = lp

        // Periodic time observer for UI progress (per-iteration position).
        let observer = qp.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let secs = CMTimeGetSeconds(time)
            Task { @MainActor in
                guard let self else { return }
                self.position = secs
                if let durSecs = self.queuePlayer?.currentItem?.duration.seconds,
                   durSecs.isFinite, durSecs > 0 {
                    self.duration = durSecs
                }
            }
        }
        previewTimeObserver = observer

        qp.play()
        isPlaying = true
    }

    // MARK: - Preview playback (one-shot)

    private func startPreviewPlayback(url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.previewPlayer = player

        previewTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let secs = CMTimeGetSeconds(time)
            Task { @MainActor in
                guard let self else { return }
                self.position = secs
                if let durSecs = self.previewPlayer?.currentItem?.duration.seconds,
                   durSecs.isFinite, durSecs > 0 {
                    self.duration = durSecs
                }
            }
        }

        previewEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePreviewEnd()
            }
        }

        player.play()
        isPlaying = true
    }

    private func handlePreviewEnd() {
        position = duration
        isPlaying = false
        // Keep currentID until the user stops or picks another, so the row
        // can show "completed" briefly.
    }

    private func teardown() {
        if let observer = previewTimeObserver {
            queuePlayer?.removeTimeObserver(observer)
            previewPlayer?.removeTimeObserver(observer)
        }
        previewTimeObserver = nil
        if let endObs = previewEndObserver {
            NotificationCenter.default.removeObserver(endObs)
        }
        previewEndObserver = nil
        looper = nil
        queuePlayer = nil
        previewPlayer = nil
    }
}
