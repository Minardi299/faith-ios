import Foundation

/// Pulls a salient verbatim quote from a `SuttaPassage` for the given user
/// query. The model never authors scripture; it only picks passage ids, and
/// this helper surfaces the actual canonical text. Query-aware so the quote
/// shown is the line(s) most directly speaking to what the user asked.
@MainActor
enum CanonQuoteExtractor {

    /// Maximum quote length, in characters. Longer than this and we
    /// truncate with an ellipsis — chat is not the place to dump a sutta.
    private static let maxQuoteChars = 320

    /// Lines that begin with one of these are skipped when no query-match
    /// is found — they're sutta-frame narrative ("Thus have I heard… At one
    /// time the Buddha was staying near Sāvatthī…"), not the teaching.
    private static let narrativeOpeners: [String] = [
        "so i have heard",
        "thus have i heard",
        "thus i have heard",
        "at one time",
        "now at that time",
        "on one occasion",
        "i heard that",
    ]

    /// Returns a verbatim quote from `passage` chosen to best answer
    /// `query`. Empty string if the passage has no body text.
    static func quote(from passage: SuttaPassage, query: String) -> String {
        let lines = passage.lines.map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return "" }

        let words = significantWords(in: query)
        if !words.isEmpty {
            // Score every line by query-token overlap. Pick the highest;
            // attach a following line if there's room (gives context).
            var bestIdx = -1
            var bestScore = 0
            for (i, line) in lines.enumerated() {
                let lowered = line.lowercased()
                let score = words.reduce(0) { acc, w in
                    acc + (lowered.contains(w) ? 1 : 0)
                }
                if score > bestScore {
                    bestScore = score
                    bestIdx = i
                }
            }
            if bestIdx >= 0 {
                return composeQuote(lines: lines, startIndex: bestIdx)
            }
        }

        // No keyword match — fall back to the first non-narrative line.
        for (i, line) in lines.enumerated() {
            let lowered = line.lowercased()
            let isNarrative = narrativeOpeners.contains { lowered.hasPrefix($0) }
            if !isNarrative, line.count > 24 {
                return composeQuote(lines: lines, startIndex: i)
            }
        }
        return composeQuote(lines: lines, startIndex: 0)
    }

    private static func significantWords(in query: String) -> [String] {
        query.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 4 && !commonStopWords.contains($0) }
    }

    private static let commonStopWords: Set<String> = [
        "what", "with", "from", "about", "this", "that", "into", "your", "have",
        "does", "doesnt", "would", "could", "should", "their", "there", "these",
        "those", "really", "actually", "going", "where", "which", "while", "when",
        "tell", "talk", "talks", "speak", "speaks", "saying",
    ]

    /// Compose a quote starting at `startIndex`, optionally including the
    /// next line if there's room. Caps at `maxQuoteChars`.
    private static func composeQuote(lines: [String], startIndex i: Int) -> String {
        guard i < lines.count else { return "" }
        var quote = lines[i]
        if quote.count < 180, i + 1 < lines.count {
            quote += " " + lines[i + 1]
        }
        if quote.count > maxQuoteChars {
            // Truncate at a sentence/word boundary if possible.
            let limited = String(quote.prefix(maxQuoteChars))
            if let lastSpace = limited.lastIndex(of: " ") {
                return String(limited[..<lastSpace]) + "…"
            }
            return limited + "…"
        }
        return quote
    }
}
