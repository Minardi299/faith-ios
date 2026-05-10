import Foundation
import Observation
import os

private let log = Logger(subsystem: "com.faith.app", category: "listenprogress")

/// Lightweight per-user pathway progress, persisted to UserDefaults so we
/// don't pay a SwiftData migration for what is fundamentally a small key/value
/// state. Stores: which pathways the user has opened, when, and which steps
/// inside each pathway they've marked as read.
@MainActor
final class PathwayProgressStore: ObservableObject {

    static let shared = PathwayProgressStore()

    struct Progress: Codable, Hashable {
        var lastOpenedAt: Date
        var readSuttaIDs: Set<String>
    }

    @Published private(set) var byPathway: [String: Progress] = [:]

    private let defaultsKey = "pathwayProgress.v1"

    private init() { load() }

    // MARK: - Public API

    func markOpened(pathwayID: String) {
        var p = byPathway[pathwayID] ?? Progress(lastOpenedAt: .now, readSuttaIDs: [])
        p.lastOpenedAt = .now
        byPathway[pathwayID] = p
        save()
    }

    func markRead(pathwayID: String, suttaID: String) {
        var p = byPathway[pathwayID] ?? Progress(lastOpenedAt: .now, readSuttaIDs: [])
        guard !p.readSuttaIDs.contains(suttaID) else { return }
        p.readSuttaIDs.insert(suttaID)
        p.lastOpenedAt = .now
        byPathway[pathwayID] = p
        save()
    }

    func unmarkRead(pathwayID: String, suttaID: String) {
        guard var p = byPathway[pathwayID], p.readSuttaIDs.contains(suttaID) else { return }
        p.readSuttaIDs.remove(suttaID)
        byPathway[pathwayID] = p
        save()
    }

    func isRead(pathwayID: String, suttaID: String) -> Bool {
        byPathway[pathwayID]?.readSuttaIDs.contains(suttaID) ?? false
    }

    func progress(pathwayID: String, totalSteps: Int) -> (read: Int, total: Int) {
        let read = byPathway[pathwayID]?.readSuttaIDs.count ?? 0
        return (read, totalSteps)
    }

    /// First not-yet-read step's index, else 0.
    func nextStepIndex(in pathway: ReadingPathway) -> Int {
        let read = byPathway[pathway.id]?.readSuttaIDs ?? []
        for (idx, step) in pathway.steps.enumerated() where !read.contains(step.suttaID) {
            return idx
        }
        return 0
    }

    /// All steps before `nextStepIndex` are considered "read." When the user
    /// finishes a track, this returns 0 (start over) — caller should also
    /// check `progress(...).read == .total` for the "completed" state.
    var activePathwayID: String? {
        byPathway.max(by: { $0.value.lastOpenedAt < $1.value.lastOpenedAt })?.key
    }

    /// Pathways the user has opened, most-recent first. Returns IDs only;
    /// resolve via `PathwayStore.shared.pathway(byID:)`.
    var startedPathwayIDs: [String] {
        byPathway
            .sorted { $0.value.lastOpenedAt > $1.value.lastOpenedAt }
            .map(\.key)
    }

    func hasStarted(pathwayID: String) -> Bool {
        byPathway[pathwayID] != nil
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([String: Progress].self, from: data)
            self.byPathway = decoded
        } catch {
            log.error("PathwayProgressStore decode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(byPathway)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            log.error("PathwayProgressStore encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Clears all in-memory pathway progress and removes the UserDefaults key.
    /// Called by AccountDeletion.wipe() to satisfy App Store 5.1.1(v).
    func reset() {
        byPathway = [:]
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
