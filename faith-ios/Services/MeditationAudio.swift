import Foundation
import AVFoundation

@MainActor
final class MeditationAudio {
    static let shared = MeditationAudio()

    private var player: AVAudioPlayer?

    func play() {
        if player == nil {
            // Drop a `meditation.mp3` into the app bundle to enable background audio.
            // Until then, this silently no-ops so the timer still works.
            guard let url = Bundle.main.url(forResource: "meditation", withExtension: "mp3") else {
                return
            }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                let p = try AVAudioPlayer(contentsOf: url)
                p.numberOfLoops = -1
                p.volume = 0.5
                p.prepareToPlay()
                player = p
            } catch {
                return
            }
        }
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
