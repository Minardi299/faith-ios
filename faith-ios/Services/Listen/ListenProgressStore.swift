import Foundation
import os

private let log = Logger(subsystem: "com.faith.app", category: "listenprogress")

/// Per-passage listening progress: how far the user got, whether they finished.
/// UserDefaults-backed with throttled writes (5s debounce) — high-frequency
/// position updates are absorbed in-memory; persistence happens on a timer or
/// on key transitions (completion, app background).
@MainActor
final class ListenProgressStore: ObservableObject {

    static let shared = ListenProgressStore()

    struct Progress: Codable, Hashable {
        var secondsListened: Int       // total accumulated time across sessions
        var lastPositionSeconds: Int   // resume offset
        var completed: Bool
        var lastListenedAt: Date
        var completedAt: Date?
    }

    @Published private(set) var byPassageID: [String: Progress] = [:]
    @Published private(set) var lastListened: RecentListenRef?

    private let defaultsKey = "listenProgress.v1"
    private let lastListenedKey = "listenProgress.lastListened.v1"
    private var pendingSave: DispatchWorkItem?
    private let debounceSeconds: TimeInterval = 5.0

    private init() { load() }

    // MARK: - Public API

    /// Record an updated position for a passage. Throttled to disk.
    func recordPosition(passageID: String,
                        seconds: Int,
                        deltaSecondsListened: Int = 0) {
        var p = byPassageID[passageID]
            ?? Progress(secondsListened: 0,
                        lastPositionSeconds: 0,
                        completed: false,
                        lastListenedAt: .now,
                        completedAt: nil)
        p.lastPositionSeconds = max(p.lastPositionSeconds, seconds)
        p.secondsListened += max(0, deltaSecondsListened)
        p.lastListenedAt = .now
        byPassageID[passageID] = p
        scheduleSave()
    }

    /// Mark complete (called when an audio source finishes naturally).
    func markCompleted(passageID: String) {
        var p = byPassageID[passageID]
            ?? Progress(secondsListened: 0,
                        lastPositionSeconds: 0,
                        completed: false,
                        lastListenedAt: .now,
                        completedAt: nil)
        p.completed = true
        p.completedAt = .now
        p.lastListenedAt = .now
        byPassageID[passageID] = p
        saveImmediately()
    }

    func resumePosition(passageID: String) -> Int {
        let p = byPassageID[passageID]
        // If already completed, start over from 0 next time.
        if p?.completed == true { return 0 }
        return p?.lastPositionSeconds ?? 0
    }

    func isCompleted(passageID: String) -> Bool {
        byPassageID[passageID]?.completed ?? false
    }

    /// Update the most-recent-listened reference (used by Continue Listening hero).
    func recordLastListened(_ ref: RecentListenRef) {
        self.lastListened = ref
        do {
            let data = try JSONEncoder().encode(ref)
            UserDefaults.standard.set(data, forKey: lastListenedKey)
        } catch {
            log.error("ListenProgressStore lastListened encode failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// (completed, total) across the items in a stage.
    func progress(stage: StudyStage) -> (completed: Int, total: Int) {
        var done = 0
        for item in stage.items {
            // An item is "complete" when all its passage IDs are complete.
            let ids = item.passageIDs
            guard !ids.isEmpty else { continue }
            if ids.allSatisfy({ isCompleted(passageID: $0) }) { done += 1 }
        }
        return (done, stage.items.count)
    }

    /// (completed, total) across all items in a track.
    func progress(track: StudyTrack) -> (completed: Int, total: Int) {
        var done = 0
        var total = 0
        for stage in track.stages {
            let p = progress(stage: stage)
            done += p.completed
            total += p.total
        }
        return (done, total)
    }

    func progressFraction(item: StudyItem) -> Double {
        let ids = item.passageIDs
        guard !ids.isEmpty else { return 0 }
        let done = ids.filter { isCompleted(passageID: $0) }.count
        return Double(done) / Double(ids.count)
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey) {
            do {
                self.byPassageID = try JSONDecoder().decode([String: Progress].self, from: data)
            } catch {
                log.error("ListenProgressStore decode failed: \(error.localizedDescription, privacy: .private)")
            }
        }
        if let data = UserDefaults.standard.data(forKey: lastListenedKey) {
            do {
                self.lastListened = try JSONDecoder().decode(RecentListenRef.self, from: data)
            } catch {
                log.error("ListenProgressStore lastListened decode failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.saveImmediately() }
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceSeconds, execute: work)
    }

    func saveImmediately() {
        pendingSave?.cancel()
        pendingSave = nil
        do {
            let data = try JSONEncoder().encode(byPassageID)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            log.error("ListenProgressStore encode failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Clears all in-memory listening progress and removes both UserDefaults
    /// keys. Called by AccountDeletion.wipe() to satisfy App Store 5.1.1(v).
    func reset() {
        pendingSave?.cancel()
        pendingSave = nil
        byPassageID = [:]
        lastListened = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: lastListenedKey)
    }
}
