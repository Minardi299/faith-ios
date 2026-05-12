import Foundation
import Observation
import os

private let log = Logger(subsystem: "com.faith.app", category: "canon")

/// Loads the bundled canon.json (built from SuttaCentral bilara-data + curated
/// Mahāyāna/Vajrayāna/Zen entries) and provides lookup APIs.
@MainActor
final class CanonStore: ObservableObject {

    static let shared = CanonStore()

    @Published private(set) var loadStatus: LoadStatus = .pending
    private(set) var entries: [SuttaPassage] = []
    private var byID: [String: SuttaPassage] = [:]
    private var byCollection: [Key: [SuttaPassage]] = [:]

    private struct Key: Hashable { let tradition: Tradition; let collectionID: String }

    enum LoadStatus: Equatable {
        case pending
        case loaded(count: Int)
        case failed(message: String)
    }

    private init() { load() }

    private struct Payload: Decodable {
        let version: Int
        let entries: [SuttaPassage]
    }

    func load() {
        // Look up first in main bundle; in test runs Bundle.main is the
        // xctest harness, so fall back to the bundle that owns this class.
        let url = Bundle.main.url(forResource: "canon", withExtension: "json")
            ?? Bundle(for: type(of: self)).url(forResource: "canon", withExtension: "json")
        guard let url else {
            loadStatus = .failed(message: "canon.json missing from app bundle")
            log.error("canon.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(Payload.self, from: data)
            var allEntries = payload.entries

            // Optionally merge story + introduction sidecars. These ship as
            // separate files so we can iterate on PD content without
            // touching canon.json.
            allEntries.append(contentsOf: loadSidecar(name: "study-stories"))
            allEntries.append(contentsOf: loadSidecar(name: "study-introductions"))

            self.entries = allEntries
            self.byID = Dictionary(allEntries.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            var grouped: [Key: [SuttaPassage]] = [:]
            for e in allEntries {
                let k = Key(tradition: e.tradition, collectionID: e.collectionID)
                grouped[k, default: []].append(e)
            }
            self.byCollection = grouped
            self.loadStatus = .loaded(count: allEntries.count)
        } catch {
            loadStatus = .failed(message: error.localizedDescription)
            log.error("canon.json decode failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func loadSidecar(name: String) -> [SuttaPassage] {
        let url = Bundle.main.url(forResource: name, withExtension: "json")
            ?? Bundle(for: type(of: self)).url(forResource: name, withExtension: "json")
        guard let url else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(Payload.self, from: data)
            return payload.entries
        } catch {
            log.warning("\(name, privacy: .public).json decode failed: \(error.localizedDescription, privacy: .private)")
            return []
        }
    }

    // MARK: - Lookup

    func passage(byID id: String) -> SuttaPassage? {
        byID[id]
    }

    func entries(for collectionID: String, tradition: Tradition) -> [SuttaPassage] {
        byCollection[Key(tradition: tradition, collectionID: collectionID)] ?? []
    }

    func search(_ query: String, limit: Int = 50) -> [SuttaPassage] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return entries.filter { p in
            p.code.lowercased().contains(q)
                || p.title.lowercased().contains(q)
                || p.englishTitle.lowercased().contains(q)
                || p.collection.lowercased().contains(q)
        }.prefix(limit).map { $0 }
    }

    // MARK: - Curated lookups

    /// All entries tagged `core` — the cross-tradition foundational reads.
    /// Returned in a fixed pedagogical order rather than insertion order.
    func coreReads() -> [SuttaPassage] {
        let order = [
            "sn56.11",   // First Sermon
            "sn22.59",   // Non-self
            "snp1.8",    // Mettā
            "an3.65",    // Kālāma
            "mn10",      // Satipaṭṭhāna (compact)
            "dn22",      // Mahāsatipaṭṭhāna (longer)
            "dhp1-20",   // Dhammapada · Pairs
            "MH_HEART",  // Heart Sūtra
        ]
        let core = entries.filter { $0.isCore }
        let map = Dictionary(uniqueKeysWithValues: core.map { ($0.id, $0) })
        return order.compactMap { map[$0] } + core.filter { !order.contains($0.id) }
    }

    /// Top-level non-stub entries for a given tradition, optionally filtered.
    func entries(for tradition: Tradition,
                 includingTags: Set<String> = []) -> [SuttaPassage] {
        entries.filter { p in
            p.tradition == tradition
                && (includingTags.isEmpty || !includingTags.isDisjoint(with: Set(p.tags)))
        }
    }

    /// Distinct collections (`(id, name, subtitle, count)`) within a tradition,
    /// derived from the loaded canon entries. Sorted by collection display name.
    func collections(for tradition: Tradition) -> [CanonCollection] {
        let scoped = entries.filter { $0.tradition == tradition }
        var seen: [String: CanonCollection] = [:]
        var counts: [String: Int] = [:]
        for entry in scoped {
            counts[entry.collectionID, default: 0] += 1
            if seen[entry.collectionID] == nil {
                seen[entry.collectionID] = CanonCollection(
                    id: entry.collectionID,
                    name: entry.collection,
                    subtitle: tradition.canonName,
                    count: 0
                )
            }
        }
        return seen.values
            .map { c in
                CanonCollection(id: c.id, name: c.name, subtitle: c.subtitle,
                                count: counts[c.id] ?? 0)
            }
            .sorted { $0.name < $1.name }
    }
}
