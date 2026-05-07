import Foundation
import AVFoundation
import Combine

/// The playback brain: holds the current item, upcoming queue, and history;
/// drives the AudioSource; persists progress; fires stage-completion events.
///
/// All views observe this store; nothing else owns playback state. Lifetime is
/// the app — the singleton is instantiated early in `FaithApp` so its
/// MPNowPlayingInfoCenter coordinator is wired before the first audio attempt.
@MainActor
final class ListenQueueStore: ObservableObject {

    static let shared = ListenQueueStore()

    // MARK: - Published state

    @Published private(set) var current: PlayableItem?
    @Published private(set) var queue: [PlayableItem] = []
    @Published private(set) var history: [PlayableItem] = []
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false
    @Published var rate: Double = 1.0 {
        didSet { source.rate = rate }
    }

    /// Fires when a stage's last item finishes. UI can show a brief overlay.
    /// `userInfo["stageID"]: String`, `userInfo["trackID"]: String`.
    static let stageCompletedNotification = Notification.Name("ListenQueueStore.stageCompleted")

    // MARK: - Internals

    private let source: AudioSource
    private let progress = ListenProgressStore.shared
    private let canon = CanonStore.shared
    private var lastPositionTickAt: Date?
    private var stoppedIntentionally = false
    private init(source: AudioSource? = nil) {
        self.source = source ?? SpeechSynthAudioSource()
        self.source.delegate = self
        self.source.rate = rate
        configureAudioSession()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    // MARK: - Public API: play

    /// Queue every item across every stage of the track in order, starting from
    /// the first item of stage 0 (or the user's resume point if any).
    func play(track: StudyTrack) {
        let items = expand(track: track)
        guard !items.isEmpty else { return }
        beginQueue(items)
    }

    /// Queue every item in this stage in order.
    func play(stage: StudyStage, in track: StudyTrack? = nil) {
        let items = expand(stage: stage, in: track)
        guard !items.isEmpty else { return }
        beginQueue(items)
    }

    /// Queue this item, plus the rest of the items after it in its stage.
    func play(item: StudyItem, in stage: StudyStage, track: StudyTrack? = nil) {
        let stageItems = expand(stage: stage, in: track)
        let startIndex = stageItems.firstIndex { $0.id.hasPrefix(item.id) || $0.passageID == item.passageIDs.first } ?? 0
        let slice = Array(stageItems.dropFirst(startIndex))
        guard !slice.isEmpty else { return }
        beginQueue(slice)
    }

    /// Single-item queue (no auto-advance to other items). Used by chat
    /// citation taps and the SuttaDetailSheet listen toggle so users don't get
    /// surprised by the next reading auto-playing.
    func play(passage: SuttaPassage) {
        let item = PlayableItem(
            id: passage.id,
            passageID: passage.id,
            displayTitle: passage.title.isEmpty ? passage.englishTitle : passage.title,
            displaySubtitle: passage.tradition.name,
            tradition: passage.tradition,
            estimatedSeconds: estimatedSeconds(for: passage),
            stageID: nil,
            trackID: nil,
            queueEyebrow: nil
        )
        beginQueue([item])
    }

    /// Single-chapter queue. After this chapter finishes, playback stops.
    func play(chapter: WorkChapter, in item: StudyItem) {
        guard let firstID = chapter.passageIDs.first,
              let passage = canon.passage(byID: firstID) else { return }
        let p = PlayableItem(
            id: "\(item.id)#\(chapter.id)",
            passageID: passage.id,
            displayTitle: item.title,
            displaySubtitle: "ch. \(chapter.number) · \(chapter.title)",
            tradition: passage.tradition,
            estimatedSeconds: chapter.estimatedMinutes * 60,
            stageID: item.stageID,
            trackID: item.trackID,
            queueEyebrow: "Chapter \(chapter.number)"
        )
        // Multi-passage chapters: also queue the trailing passages of this chapter.
        var queue: [PlayableItem] = [p]
        for (i, pid) in chapter.passageIDs.dropFirst().enumerated() {
            guard let pp = canon.passage(byID: pid) else { continue }
            queue.append(PlayableItem(
                id: "\(item.id)#\(chapter.id).\(i + 2)",
                passageID: pp.id,
                displayTitle: item.title,
                displaySubtitle: "ch. \(chapter.number) · \(chapter.title) · \(i + 2)",
                tradition: pp.tradition,
                estimatedSeconds: estimatedSeconds(for: pp),
                stageID: item.stageID,
                trackID: item.trackID,
                queueEyebrow: "Chapter \(chapter.number)"
            ))
        }
        beginQueue(queue)
    }

    // MARK: - Public API: transport

    func togglePlayPause() {
        guard current != nil else { return }
        if isPlaying { source.pause() }
        else { source.play() }
    }

    func next() {
        // Force-advance regardless of natural completion.
        stoppedIntentionally = true
        source.stop()
        advance(naturalCompletion: false)
    }

    func previous() {
        guard let last = history.popLast() else {
            // Restart current.
            seek(to: 0)
            return
        }
        if let cur = current { queue.insert(cur, at: 0) }
        loadAndPlay(last)
    }

    func seek(to seconds: TimeInterval) {
        source.seek(to: seconds)
    }

    func stop() {
        stoppedIntentionally = true
        source.stop()
        flushTickAccumulation()
        current = nil
        queue = []
        history = []
        isPlaying = false
        position = 0
        duration = 0
    }

    func clear() { stop() }

    // MARK: - Expansion helpers

    private func expand(track: StudyTrack) -> [PlayableItem] {
        var out: [PlayableItem] = []
        for stage in track.stages { out.append(contentsOf: expand(stage: stage, in: track)) }
        return out
    }

    private func expand(stage: StudyStage, in track: StudyTrack? = nil) -> [PlayableItem] {
        var out: [PlayableItem] = []
        let stageTotal = stage.items.count
        for (idx, item) in stage.items.enumerated() {
            let eyebrow = "Stage \(stage.number) · \(idx + 1) of \(stageTotal)"
            switch item.body {
            case .single(let pid):
                guard let p = canon.passage(byID: pid) else {
                    // Metadata-only fallback: synthesize a placeholder passage.
                    out.append(metadataOnlyPlayable(item: item, stage: stage, track: track, eyebrow: eyebrow))
                    continue
                }
                out.append(PlayableItem(
                    id: item.id,
                    passageID: p.id,
                    displayTitle: item.title,
                    displaySubtitle: item.subtitle ?? p.tradition.name,
                    tradition: p.tradition,
                    estimatedSeconds: max(item.estimatedMinutes * 60, estimatedSeconds(for: p)),
                    stageID: stage.id,
                    trackID: track?.id ?? item.trackID,
                    queueEyebrow: eyebrow
                ))
            case .work(_, let chapters):
                for chapter in chapters {
                    for (cidx, pid) in chapter.passageIDs.enumerated() {
                        guard let p = canon.passage(byID: pid) else { continue }
                        out.append(PlayableItem(
                            id: "\(item.id)#\(chapter.id).\(cidx + 1)",
                            passageID: p.id,
                            displayTitle: item.title,
                            displaySubtitle: "ch. \(chapter.number) · \(chapter.title)",
                            tradition: p.tradition,
                            estimatedSeconds: max(chapter.estimatedMinutes * 60, estimatedSeconds(for: p)),
                            stageID: stage.id,
                            trackID: track?.id ?? item.trackID,
                            queueEyebrow: eyebrow
                        ))
                    }
                }
            }
        }
        return out
    }

    private func metadataOnlyPlayable(item: StudyItem,
                                      stage: StudyStage,
                                      track: StudyTrack?,
                                      eyebrow: String) -> PlayableItem {
        // Synthesize a passage on-the-fly so the source has something to speak.
        // The audio source's metadataBlurb fallback handles empty `lines`.
        return PlayableItem(
            id: item.id,
            passageID: item.passageIDs.first ?? "meta.\(item.id)",
            displayTitle: item.title,
            displaySubtitle: item.subtitle ?? "Metadata only",
            tradition: track?.tradition ?? .secular,
            estimatedSeconds: max(30, item.estimatedMinutes * 60),
            stageID: stage.id,
            trackID: track?.id ?? item.trackID,
            queueEyebrow: eyebrow
        )
    }

    private func estimatedSeconds(for passage: SuttaPassage) -> Int {
        // Match SpeechSynthAudioSource WPM: 170 * 0.92 ≈ 156 wpm at 1.0× rate.
        let wpm = 170.0 * 0.92
        let words = max(1, passage.wordCount)
        return Int(Double(words) / wpm * 60.0)
    }

    // MARK: - Queue control

    private func beginQueue(_ items: [PlayableItem]) {
        guard !items.isEmpty else { return }
        flushTickAccumulation()
        history = []
        queue = Array(items.dropFirst())
        let first = items[0]
        loadAndPlay(first)
    }

    private func loadAndPlay(_ item: PlayableItem) {
        guard let passage = passageFor(item) else {
            // Skip items whose passage didn't resolve.
            advance(naturalCompletion: true)
            return
        }
        current = item
        let resume = TimeInterval(progress.resumePosition(passageID: item.passageID))
        source.load(item: item, passage: passage, startAt: resume)
        position = resume
        duration = max(source.duration, Double(item.estimatedSeconds))
        stoppedIntentionally = false
        source.play()
        recordRecent(item: item)
    }

    private func passageFor(_ item: PlayableItem) -> SuttaPassage? {
        if let p = canon.passage(byID: item.passageID) { return p }
        // Synthesize a metadata-only passage so the source can read the blurb.
        guard item.passageID.hasPrefix("meta.") else { return nil }
        return SuttaPassage(
            id: item.passageID,
            code: "",
            title: item.displayTitle,
            englishTitle: "",
            tradition: item.tradition,
            collection: "",
            collectionID: "",
            lines: [],
            isStub: false,
            wordCount: 6,
            readingMinutes: 1,
            lengthTier: .short,
            tags: [],
            kind: .commentary,
            narrator: nil,
            audioScript: nil,
            attribution: nil
        )
    }

    private func advance(naturalCompletion: Bool) {
        let finished = current
        flushTickAccumulation()

        // Mark complete if natural finish.
        if naturalCompletion, let f = finished {
            progress.markCompleted(passageID: f.passageID)
        }
        if let f = finished { history.append(f) }

        if queue.isEmpty {
            current = nil
            isPlaying = false
            position = 0
            duration = 0
            // Stage-completed event for the just-finished item's stage.
            if naturalCompletion, let f = finished, let stageID = f.stageID {
                NotificationCenter.default.post(
                    name: ListenQueueStore.stageCompletedNotification,
                    object: nil,
                    userInfo: [
                        "stageID": stageID,
                        "trackID": f.trackID ?? ""
                    ]
                )
            }
            return
        }

        let next = queue.removeFirst()
        // Cross-stage transition? Fire stage-completed for the previous one.
        if naturalCompletion,
           let f = finished,
           let prevStage = f.stageID,
           next.stageID != prevStage {
            NotificationCenter.default.post(
                name: ListenQueueStore.stageCompletedNotification,
                object: nil,
                userInfo: [
                    "stageID": prevStage,
                    "trackID": f.trackID ?? ""
                ]
            )
        }
        loadAndPlay(next)
    }

    // MARK: - Tick accounting

    private func flushTickAccumulation() {
        guard let cur = current else { lastPositionTickAt = nil; return }
        if let last = lastPositionTickAt {
            let delta = Int(Date().timeIntervalSince(last))
            if delta > 0 {
                progress.recordPosition(
                    passageID: cur.passageID,
                    seconds: Int(position),
                    deltaSecondsListened: delta
                )
            }
        }
        lastPositionTickAt = nil
    }

    private func recordRecent(item: PlayableItem) {
        let ref = RecentListenRef(
            trackID: item.trackID,
            stageID: item.stageID,
            itemID: item.id,
            passageID: item.passageID,
            lastPositionSeconds: Int(position),
            estimatedSeconds: item.estimatedSeconds,
            lastListenedAt: .now
        )
        progress.recordLastListened(ref)
    }
}

// MARK: - AudioSourceDelegate

extension ListenQueueStore: AudioSourceDelegate {
    func audioSourceDidStartPlaying(_ source: AudioSource) {
        isPlaying = true
        duration = source.duration
        lastPositionTickAt = Date()
    }

    func audioSourceDidPause(_ source: AudioSource) {
        isPlaying = false
        flushTickAccumulation()
    }

    func audioSourceDidFinish(_ source: AudioSource, naturally: Bool) {
        isPlaying = false
        if !stoppedIntentionally {
            advance(naturalCompletion: naturally)
        }
    }

    func audioSource(_ source: AudioSource, didTickPosition pos: TimeInterval) {
        position = pos
        duration = max(duration, source.duration)
        // Throttle disk writes: ListenProgressStore.recordPosition is debounced.
        if let cur = current {
            let now = Date()
            let delta: Int
            if let last = lastPositionTickAt {
                delta = max(0, Int(now.timeIntervalSince(last)))
            } else {
                delta = 0
            }
            lastPositionTickAt = now
            progress.recordPosition(
                passageID: cur.passageID,
                seconds: Int(pos),
                deltaSecondsListened: delta
            )
        }
    }
}
