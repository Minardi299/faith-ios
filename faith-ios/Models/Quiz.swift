import Foundation

struct QuizQuestion: Identifiable, Codable, Hashable {
    let tradition: String      // raw value
    let passageID: String
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String

    var id: String { "\(tradition)·\(passageID)·\(prompt.prefix(24))" }

    var traditionEnum: Tradition? { Tradition(rawValue: tradition) }
}

@MainActor
final class QuizStore {
    static let shared = QuizStore()

    private(set) var all: [QuizQuestion] = []

    private init() { load() }

    private struct Payload: Codable {
        let version: Int
        let questions: [QuizQuestion]
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "quiz", withExtension: "json") else {
            print("⚠️ quiz.json missing")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            all = payload.questions
        } catch {
            print("⚠️ quiz.json decode failed: \(error)")
        }
    }

    /// Pick `count` questions, optionally filtered to a tradition.
    func pickRound(_ count: Int = 10, tradition: Tradition? = nil) -> [QuizQuestion] {
        let pool = tradition.map { t in all.filter { $0.tradition == t.rawValue } } ?? all
        return Array(pool.shuffled().prefix(count))
    }
}
