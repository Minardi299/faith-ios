import Foundation

/// Pre-LLM crisis classifier — detects self-harm language in user input and
/// triggers a fixed deflection card. Phase 1.5 wires the interactive intercept card.
/// Biased toward false positives.
/// Per design (M3d): if positive, replace AI response with one fixed line.
enum CrisisClassifier {
    private static let crisisTokens: [String] = [
        "kill myself", "end it", "end my life", "suicid", "want to die",
        "i don't want to be alive", "no reason to live", "hurt myself",
        "hurting myself", "self harm", "self-harm", "can't go on",
        "give up on life", "no point in living"
    ]

    private static let normalizedTokens: [String] = crisisTokens.map(normalize)

    static let interceptMessage = "What you said sounds heavy. Maybe step away from the screen for a bit. The chat will be here when you come back."

    /// Global helpline aggregator — appropriate for a multi-language audience.
    static let helplineURL = URL(string: "https://findahelpline.com/")!

    static func detects(in input: String) -> Bool {
        let normalized = normalize(input)
        return normalizedTokens.contains { normalized.contains($0) }
    }

    /// Folds case + diacritics and normalizes smart quotes / Unicode hyphen
    /// variants so they don't bypass token matching. iOS keyboards default
    /// to smart-quote substitution, which broke the prior `lowercased()` path.
    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "\u{2018}", with: "'")  // left single quote
            .replacingOccurrences(of: "\u{2019}", with: "'")  // right single quote (smart apostrophe)
            .replacingOccurrences(of: "\u{2010}", with: "-")  // hyphen
            .replacingOccurrences(of: "\u{2011}", with: "-")  // non-breaking hyphen
            .replacingOccurrences(of: "\u{2013}", with: "-")  // en dash
            .replacingOccurrences(of: "\u{2014}", with: "-")  // em dash
    }
}
