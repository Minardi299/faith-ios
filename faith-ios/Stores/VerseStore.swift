import Foundation

@Observable
final class VerseStore {
    let verses: [Verse]

    init() {
        self.verses = Self.load()
    }

    private static func load() -> [Verse] {
        guard let url = Bundle.main.url(forResource: "data", withExtension: "json") else {
            assertionFailure("data.json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Verse].self, from: data)
        } catch {
            assertionFailure("Failed to decode data.json: \(error)")
            return []
        }
    }

    func verse(for date: Date) -> Verse? {
        guard !verses.isEmpty else { return nil }
        let day = Calendar.current.startOfDay(for: date)
        let epoch = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 0))
        let days = Calendar.current.dateComponents([.day], from: epoch, to: day).day ?? 0
        let index = ((days % verses.count) + verses.count) % verses.count
        return verses[index]
    }

    func verse(number: Int) -> Verse? {
        verses.first { $0.number == number }
    }
}
