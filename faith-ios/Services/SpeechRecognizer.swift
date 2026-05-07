import Foundation
import AVFoundation
import Speech

/// Push-to-talk speech recognition via `SFSpeechRecognizer` + `AVAudioEngine`.
/// Streams partial transcriptions to a published `transcript` string while
/// listening; the chat composer binds the text field to that transcript so
/// the user sees their words appear live, then taps the mic again to commit.
///
/// Prefers on-device recognition (`requiresOnDeviceRecognition = true`) so
/// the audio stays on the phone, matching the rest of the app's privacy model.
@MainActor
final class SpeechRecognizer: ObservableObject {

    static let shared = SpeechRecognizer()

    @Published private(set) var transcript: String = ""
    @Published private(set) var isListening: Bool = false
    @Published private(set) var lastError: String?

    private let recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private init() {}

    /// Toggle listen on/off. Asks for permissions on first use.
    func toggle() {
        if isListening { stop() } else { Task { await start() } }
    }

    func start() async {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            lastError = "Speech recognition unavailable"
            return
        }
        let speechAuth = await requestSpeechAuthorization()
        guard speechAuth == .authorized else {
            lastError = "Speech permission denied"
            return
        }
        let micGranted = await requestMicrophoneAuthorization()
        guard micGranted else {
            lastError = "Microphone permission denied"
            return
        }

        do {
            try beginRecording(recognizer: recognizer)
        } catch {
            lastError = "Audio session: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isListening = false
    }

    /// Reset transcript to empty (caller does this when user commits / sends).
    func reset() {
        transcript = ""
    }

    // MARK: - Internals

    private func beginRecording(recognizer: SFSpeechRecognizer) throws {
        // Stop any prior session.
        stop()
        transcript = ""
        lastError = nil

        // Use .playAndRecord so any active chant/background playback isn't
        // torn down when the user taps the mic — they can coexist with the
        // mic input. .duckOthers is enough; .mixWithOthers keeps system
        // sounds alive too.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.stop()
                    }
                }
                if let error {
                    let nsError = error as NSError
                    // 1110 = no speech detected; quietly ignore. Other errors surface.
                    if nsError.code != 1110 {
                        self.lastError = error.localizedDescription
                    }
                    self.stop()
                }
            }
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
