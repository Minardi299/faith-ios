import Foundation
import os

private let log = Logger(subsystem: "com.faith.app", category: "studytracks")

/// Loads `study-tracks.json` and exposes lookups by track / stage / item.
/// Mirrors the `PathwayStore` pattern.
@MainActor
final class StudyTrackStore: ObservableObject {

    static let shared = StudyTrackStore()

    @Published private(set) var loadStatus: LoadStatus = .pending
    @Published private(set) var tracks: [StudyTrack] = []
    private var byTrackID: [String: StudyTrack] = [:]
    private var stageByID: [String: StudyStage] = [:]
    private var itemByID: [String: StudyItem] = [:]

    enum LoadStatus: Equatable {
        case pending
        case loaded(count: Int)
        case failed(message: String)
    }

    private init() { load() }

    private struct Payload: Decodable {
        let version: Int
        let tracks: [StudyTrack]
    }

    func load() {
        let url = Bundle.main.url(forResource: "study-tracks", withExtension: "json")
            ?? Bundle(for: type(of: self)).url(forResource: "study-tracks", withExtension: "json")
        guard let url else {
            loadStatus = .failed(message: "study-tracks.json missing from bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            self.tracks = payload.tracks
            self.byTrackID = Dictionary(uniqueKeysWithValues: payload.tracks.map { ($0.id, $0) })
            for t in payload.tracks {
                for s in t.stages {
                    stageByID[s.id] = s
                    for i in s.items { itemByID[i.id] = i }
                }
            }
            loadStatus = .loaded(count: payload.tracks.count)
        } catch {
            loadStatus = .failed(message: error.localizedDescription)
            log.error("study-tracks.json decode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Lookup

    func track(byID id: String) -> StudyTrack? { byTrackID[id] }
    func track(for tradition: Tradition) -> StudyTrack? {
        tracks.first { $0.tradition == tradition }
    }
    func stage(byID id: String) -> StudyStage? { stageByID[id] }
    func item(byID id: String) -> StudyItem? { itemByID[id] }

    /// Resolve the parent stage and track for a given item.
    func parents(of item: StudyItem) -> (track: StudyTrack, stage: StudyStage)? {
        guard let stage = stage(byID: item.stageID),
              let track = track(byID: item.trackID) else { return nil }
        return (track, stage)
    }
}
