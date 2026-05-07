import Foundation
import AVFoundation
import Combine

@MainActor
protocol AudioService: AnyObject {
    var isSpeaking: Bool { get }
    var currentTitle: String? { get }
    func speak(text: String, title: String)
    func togglePauseResume()
    func stop()
    func playBell()
    func startGuidedSit(minutes: Int)
}

@MainActor
final class LiveAudioService: NSObject, AudioService, ObservableObject {
    static let shared = LiveAudioService()

    private let synth = AVSpeechSynthesizer()
    private var bellPlayer: AVAudioPlayer?
    private var sitTask: Task<Void, Never>?

    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var currentTitle: String? = nil

    private override init() {
        super.init()
        synth.delegate = self
        configureSession()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    func speak(text: String, title: String) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        currentTitle = title
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 0.97
        utterance.preUtteranceDelay = 0.2
        synth.speak(utterance)
        isSpeaking = true
    }

    func togglePauseResume() {
        if synth.isPaused {
            synth.continueSpeaking()
        } else if synth.isSpeaking {
            synth.pauseSpeaking(at: .word)
        }
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        sitTask?.cancel()
        sitTask = nil
        isSpeaking = false
        currentTitle = nil
    }

    func playBell() {
        // Use a system sound; if a bundled file is present, prefer it.
        if let url = Bundle.main.url(forResource: "bell", withExtension: "caf")
            ?? Bundle.main.url(forResource: "bell", withExtension: "wav")
            ?? Bundle.main.url(forResource: "bell", withExtension: "m4a") {
            do {
                bellPlayer = try AVAudioPlayer(contentsOf: url)
                bellPlayer?.volume = 0.8
                bellPlayer?.play()
                return
            } catch {
                print("⚠️ bell sample failed: \(error)")
            }
        }
        // Fallback: a soft synthetic bell via the speech synthesizer (one note tone).
        let utterance = AVSpeechUtterance(string: " ")
        utterance.preUtteranceDelay = 0.05
        synth.speak(utterance)
    }

    /// 5-min ānāpānasati script (or scaled to N minutes) — opens with a bell, then
    /// soft cue lines spaced over the duration, closes with a bell.
    func startGuidedSit(minutes: Int) {
        sitTask?.cancel()
        let openingScript = "Settling in. Let the body arrive. The breath is coming and going on its own — there is nothing to do but notice."
        let cues = [
            "Notice where the breath touches the body. The nostrils. The chest. The belly.",
            "When the mind wanders, just return — gently, without judgment.",
            "Breathing in, you know you are breathing in. Breathing out, you know you are breathing out.",
            "If a thought arrives, you don't have to push it away. Let it pass like a cloud.",
            "Come back to the breath. This one. Not the next one."
        ]
        let closingScript = "Bringing the practice to a close. Letting the breath continue on its own. Opening the eyes when ready."

        playBell()
        speak(text: openingScript, title: "Anāpānasati — \(minutes) min")

        let totalSeconds = minutes * 60
        let cueGap = max(40, totalSeconds / max(1, cues.count + 2))

        sitTask = Task { [weak self] in
            for (i, cue) in cues.enumerated() {
                try? await Task.sleep(nanoseconds: UInt64(cueGap) * 1_000_000_000)
                if Task.isCancelled { return }
                await MainActor.run { [weak self] in
                    self?.speak(text: cue, title: "Anāpānasati — \(minutes) min · cue \(i + 1)")
                }
            }
            try? await Task.sleep(nanoseconds: UInt64(cueGap) * 1_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run { [weak self] in
                self?.speak(text: closingScript, title: "Anāpānasati — closing")
            }
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run { [weak self] in
                self?.playBell()
            }
        }
    }
}

extension LiveAudioService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !LiveAudioService.shared.synth.isSpeaking {
                LiveAudioService.shared.isSpeaking = false
                LiveAudioService.shared.currentTitle = nil
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            LiveAudioService.shared.isSpeaking = true
        }
    }
}
