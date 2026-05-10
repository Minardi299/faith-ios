import Foundation
import Observation
import os

private let log = Logger(subsystem: "com.faith.app", category: "pathways")

/// Loads bundled `pathways.json` (curated reading sequences per tradition).
@MainActor
final class PathwayStore: ObservableObject {

    static let shared = PathwayStore()

    @Published private(set) var pathways: [ReadingPathway] = []

    private init() { load() }

    private struct Payload: Decodable {
        let version: Int
        let pathways: [ReadingPathway]
    }

    func load() {
        let url = Bundle.main.url(forResource: "pathways", withExtension: "json")
            ?? Bundle(for: type(of: self)).url(forResource: "pathways", withExtension: "json")
        guard let url else {
            log.error("pathways.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            self.pathways = payload.pathways
        } catch {
            log.error("pathways.json decode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// All pathways for one tradition.
    func pathways(for tradition: Tradition) -> [ReadingPathway] {
        pathways.filter { $0.tradition == tradition }
    }

    /// Pathways for the user's tradition first, others below in canonical order.
    func pathways(prioritizing tradition: Tradition) -> [ReadingPathway] {
        let priority = pathways.filter { $0.tradition == tradition }
        let order: [Tradition] = [.theravada, .mahayana, .vajrayana, .zen, .secular]
        let rest = order
            .filter { $0 != tradition }
            .flatMap { t in pathways.filter { $0.tradition == t } }
        return priority + rest
    }

    func pathway(byID id: String) -> ReadingPathway? {
        pathways.first { $0.id == id }
    }
}
