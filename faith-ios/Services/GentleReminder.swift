import Foundation

/// Lightweight pre-LLM crisis classifier. Biased toward false positives.
/// Per design (M3d): if positive, replace AI response with one fixed line.
enum GentleReminder {
    private static let crisisTokens: [String] = [
        "kill myself", "end it", "end my life", "suicid", "want to die",
        "i don't want to be alive", "no reason to live", "hurt myself",
        "hurting myself", "self harm", "self-harm", "can't go on",
        "give up on life", "no point in living"
    ]

    static let line = "What you said sounds heavy. Maybe step away from the screen for a bit. The chat will be here when you come back."

    static func shouldFire(on input: String) -> Bool {
        let lower = input.lowercased()
        return crisisTokens.contains { lower.contains($0) }
    }
}
