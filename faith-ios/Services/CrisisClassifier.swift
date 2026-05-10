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

    static let interceptMessage = "What you said sounds heavy. Maybe step away from the screen for a bit. The chat will be here when you come back."

    /// Global helpline aggregator — appropriate for a multi-language audience.
    static let helplineURL = URL(string: "https://findahelpline.com/")!

    static func detects(in input: String) -> Bool {
        let lower = input.lowercased()
        return crisisTokens.contains { lower.contains($0) }
    }
}
