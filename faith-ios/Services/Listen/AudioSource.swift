import Foundation
import AVFoundation

/// Abstraction over the audio backend so the queue and views are decoupled from
/// the concrete speech / pre-recorded / streaming implementation.
///
/// Today the only impl is `SpeechSynthAudioSource` (AVSpeechSynthesizer).
/// Tomorrow we drop in a `PrerecordedAudioSource` (AVPlayer) or an
/// ElevenLabs-streaming source without touching `ListenQueueStore` or views.
@MainActor
protocol AudioSource: AnyObject {
    var delegate: AudioSourceDelegate? { get set }
    var position: TimeInterval { get }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }
    var rate: Double { get set }     // 0.8 / 1.0 / 1.2

    func load(item: PlayableItem, passage: SuttaPassage, startAt: TimeInterval)
    func play()
    func pause()
    func stop()
    func seek(to seconds: TimeInterval)
}

@MainActor
protocol AudioSourceDelegate: AnyObject {
    func audioSourceDidStartPlaying(_ source: AudioSource)
    func audioSourceDidPause(_ source: AudioSource)
    func audioSourceDidFinish(_ source: AudioSource, naturally: Bool)
    func audioSource(_ source: AudioSource, didTickPosition pos: TimeInterval)
}

/// AVSpeechSynthesizer-backed source. Estimates duration from word count, tracks
/// position via `willSpeakRangeOfSpeechString` plus a smooth wall-clock
/// interpolation timer between word boundaries. Resume granularity is
/// line-level (re-utters from the nearest line break ≥ target offset).
@MainActor
final class SpeechSynthAudioSource: NSObject, AudioSource {
    weak var delegate: AudioSourceDelegate?
    private(set) var position: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying: Bool = false
    var rate: Double = 1.0 {
        didSet {
            // Rate change re-scales the duration estimate.
            recomputeDurationEstimate()
        }
    }

    private let synth = AVSpeechSynthesizer()
    private var loadedPassage: SuttaPassage?
    private var loadedItem: PlayableItem?
    private var lineSegments: [LineSegment] = []
    private var currentLineIndex: Int = 0
    private var wordsSpokenInCurrentLine: Int = 0
    private var positionAtSegmentStart: TimeInterval = 0
    private var interpolationTimer: Timer?
    private var lastTickAt: Date?

    /// One spoken line + its cumulative word and second offsets.
    private struct LineSegment {
        let text: String
        let wordCount: Int
        let cumulativeWordsBefore: Int
        let startSecond: TimeInterval
        let estimatedSeconds: TimeInterval
    }

    override init() {
        super.init()
        synth.delegate = self
    }

    func load(item: PlayableItem, passage: SuttaPassage, startAt: TimeInterval) {
        // Hard reset.
        synth.stopSpeaking(at: .immediate)
        stopInterpolation()

        loadedItem = item
        loadedPassage = passage
        lineSegments = Self.buildSegments(for: passage, rate: rate)
        duration = lineSegments.last.map { $0.startSecond + $0.estimatedSeconds } ?? Double(item.estimatedSeconds)
        if duration <= 0 { duration = max(1, Double(item.estimatedSeconds)) }
        currentLineIndex = nearestLineIndex(forSecond: startAt)
        wordsSpokenInCurrentLine = 0
        positionAtSegmentStart = lineSegments.indices.contains(currentLineIndex)
            ? lineSegments[currentLineIndex].startSecond
            : 0
        position = positionAtSegmentStart
        isPlaying = false
    }

    func play() {
        guard let passage = loadedPassage else { return }
        if synth.isPaused {
            synth.continueSpeaking()
            isPlaying = true
            startInterpolation()
            delegate?.audioSourceDidStartPlaying(self)
            return
        }
        // Fresh start (or restart after stop).
        if lineSegments.isEmpty || currentLineIndex >= lineSegments.count {
            // Nothing to speak — synthesize a brief metadata blurb.
            let blurb = metadataBlurb(for: passage)
            speakUtterance(text: blurb, lineIndex: 0)
        } else {
            speakFromCurrentLine()
        }
    }

    func pause() {
        if synth.isSpeaking {
            synth.pauseSpeaking(at: .word)
        }
        isPlaying = false
        stopInterpolation()
        delegate?.audioSourceDidPause(self)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isPlaying = false
        stopInterpolation()
    }

    func seek(to seconds: TimeInterval) {
        let clamped = max(0, min(seconds, duration))
        let wasPlaying = isPlaying
        synth.stopSpeaking(at: .immediate)
        stopInterpolation()
        currentLineIndex = nearestLineIndex(forSecond: clamped)
        wordsSpokenInCurrentLine = 0
        positionAtSegmentStart = lineSegments.indices.contains(currentLineIndex)
            ? lineSegments[currentLineIndex].startSecond
            : 0
        position = positionAtSegmentStart
        delegate?.audioSource(self, didTickPosition: position)
        if wasPlaying { play() }
    }

    // MARK: - Internals

    private func speakFromCurrentLine() {
        guard lineSegments.indices.contains(currentLineIndex) else {
            isPlaying = false
            delegate?.audioSourceDidFinish(self, naturally: true)
            return
        }
        let segment = lineSegments[currentLineIndex]
        speakUtterance(text: segment.text, lineIndex: currentLineIndex)
    }

    private func speakUtterance(text: String, lineIndex: Int) {
        wordsSpokenInCurrentLine = 0
        positionAtSegmentStart = lineSegments.indices.contains(lineIndex)
            ? lineSegments[lineIndex].startSecond
            : position
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(0.92 * rate)
        utterance.pitchMultiplier = 0.97
        utterance.preUtteranceDelay = lineIndex == 0 ? 0.2 : 0.0
        synth.speak(utterance)
        isPlaying = true
        startInterpolation()
        if lineIndex == currentLineIndex {
            delegate?.audioSourceDidStartPlaying(self)
        }
    }

    private func metadataBlurb(for passage: SuttaPassage) -> String {
        // ✍ metadata-only items: read a short factual line so the queue still
        // ticks and auto-advances. No spiritual content authored here.
        var parts: [String] = [passage.title]
        if !passage.englishTitle.isEmpty, passage.englishTitle != passage.title {
            parts.append(passage.englishTitle)
        }
        parts.append(passage.tradition.name)
        if !passage.collection.isEmpty { parts.append(passage.collection) }
        return parts.joined(separator: ". ") + "."
    }

    private func recomputeDurationEstimate() {
        guard let passage = loadedPassage else { return }
        lineSegments = Self.buildSegments(for: passage, rate: rate)
        duration = lineSegments.last.map { $0.startSecond + $0.estimatedSeconds } ?? duration
    }

    private func nearestLineIndex(forSecond second: TimeInterval) -> Int {
        guard !lineSegments.isEmpty else { return 0 }
        for (i, seg) in lineSegments.enumerated() {
            if seg.startSecond + seg.estimatedSeconds > second { return i }
        }
        return lineSegments.count
    }

    private func startInterpolation() {
        stopInterpolation()
        lastTickAt = Date()
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickInterpolation()
            }
        }
    }

    private func stopInterpolation() {
        interpolationTimer?.invalidate()
        interpolationTimer = nil
        lastTickAt = nil
    }

    private func tickInterpolation() {
        guard isPlaying, let last = lastTickAt else { return }
        let now = Date()
        let delta = now.timeIntervalSince(last)
        lastTickAt = now
        // Smooth the position forward by wall-clock delta. The next
        // willSpeakRangeOfSpeechString correction will snap it to truth.
        position = min(duration, position + delta)
        delegate?.audioSource(self, didTickPosition: position)
    }

    /// Build per-line segments with cumulative offsets. Words-per-minute is
    /// derived from the AVSpeechUtterance default rate (~170 WPM) modulated by
    /// our own 0.92 base + user-selected `rate`.
    private static func buildSegments(for passage: SuttaPassage, rate: Double) -> [LineSegment] {
        let baseWPM: Double = 170 * 0.92 * rate
        var segments: [LineSegment] = []
        var cumulativeWords = 0
        var cumulativeSeconds: TimeInterval = 0
        let lines = passage.lines.isEmpty
            ? [SuttaLine(number: nil, text: passage.title)]
            : passage.lines
        for line in lines {
            let words = max(1, line.text.split { !$0.isLetter && !$0.isNumber }.count)
            let seconds = max(0.5, Double(words) / baseWPM * 60.0)
            segments.append(LineSegment(
                text: line.text,
                wordCount: words,
                cumulativeWordsBefore: cumulativeWords,
                startSecond: cumulativeSeconds,
                estimatedSeconds: seconds
            ))
            cumulativeWords += words
            cumulativeSeconds += seconds
        }
        return segments
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechSynthAudioSource: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.handleUtteranceFinished()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        // Capture the immutable string locally — AVSpeechUtterance is not Sendable.
        let text = utterance.speechString
        Task { @MainActor in
            self.handleWordBoundary(range: characterRange, in: text)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        // Cancelled (stop or seek). Don't auto-advance; let the queue decide.
    }

    @MainActor
    private func handleUtteranceFinished() {
        // Move to next line, or finish naturally if exhausted.
        currentLineIndex += 1
        if currentLineIndex < lineSegments.count {
            speakFromCurrentLine()
        } else {
            isPlaying = false
            stopInterpolation()
            position = duration
            delegate?.audioSource(self, didTickPosition: position)
            delegate?.audioSourceDidFinish(self, naturally: true)
        }
    }

    @MainActor
    private func handleWordBoundary(range: NSRange, in text: String) {
        guard lineSegments.indices.contains(currentLineIndex) else { return }
        let segment = lineSegments[currentLineIndex]
        // Count words up to the start of this range.
        let prefix: String
        if let r = Range(NSRange(location: 0, length: range.location), in: text) {
            prefix = String(text[r])
        } else {
            prefix = ""
        }
        let wordsBefore = max(0, prefix.split { !$0.isLetter && !$0.isNumber }.count)
        wordsSpokenInCurrentLine = wordsBefore
        let progressInSegment = Double(wordsBefore) / Double(max(1, segment.wordCount))
        position = segment.startSecond + progressInSegment * segment.estimatedSeconds
        delegate?.audioSource(self, didTickPosition: position)
    }
}
