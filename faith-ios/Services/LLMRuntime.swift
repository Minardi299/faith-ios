import Foundation

@MainActor
protocol LLMRuntime: AnyObject {
    /// Non-streaming reply — used for retrieval-only fallback and previews.
    func reply(to prompt: String,
               tradition: Tradition,
               history: [ChatMessage]) async -> [MessageSegment]

    /// Streaming reply. Each emission is the FULL set of segments rendered
    /// SO FAR (replace, don't append), so the consumer can swap the
    /// rendered message in place. The final emission is the completed
    /// response. Default bridges from `reply()` with a single emission.
    func streamReply(to prompt: String,
                     tradition: Tradition,
                     history: [ChatMessage]) -> AsyncStream<[MessageSegment]>
}

extension LLMRuntime {
    func streamReply(to prompt: String,
                     tradition: Tradition,
                     history: [ChatMessage]) -> AsyncStream<[MessageSegment]> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                let segments = await self.reply(to: prompt, tradition: tradition, history: history)
                continuation.yield(segments)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
final class MockLLMRuntime: LLMRuntime {
    func reply(to prompt: String,
               tradition: Tradition,
               history: [ChatMessage]) async -> [MessageSegment] {
        try? await Task.sleep(nanoseconds: 600_000_000)
        let lower = prompt.lowercased()

        // route to a few illustrative responses with REAL citations from SeedContent
        if lower.contains("anger") || lower.contains("hatred") {
            return [
                .italic("Khanti"),
                .text(" — patience — is what the Buddha asks of us when the heart goes hot. In the "),
                .citation(SuttaCite(code: "MN 21", englishTitle: "The Simile of the Saw", suttaID: "mn21")),
                .text(", he tells the monks: even were bandits to carve them up limb by limb, the one who lets his heart get angered would not be doing his bidding. The teaching is not that the body is unbreakable. It is that the mind can be."),
            ]
        }
        if lower.contains("breath") || lower.contains("breathing") || lower.contains("meditate") {
            return [
                .italic("Ānāpānasati"),
                .text(" — mindfulness of breathing. The "),
                .citation(SuttaCite(code: "MN 10", englishTitle: "Mindfulness Meditation", suttaID: "mn10")),
                .text(" gives the instruction simply: breathing in long, he discerns 'I am breathing in long.' That is the whole gate. Not a method on top of the breath; the breath itself becoming knowable."),
            ]
        }
        if lower.contains("grief") || lower.contains("loss") || lower.contains("died") {
            return [
                .text("Grief is one of the truths the Buddha names directly. In the "),
                .citation(SuttaCite(code: "Dhp · Pairs", englishTitle: "Yamakavagga", suttaID: "dhp1-20")),
                .text(", he writes: hatred is never appeased by hatred; by non-hatred alone is hatred appeased. It is an eternal law. The same is asked of grief — to hold it without trying to push it through, until the holding itself becomes spacious."),
            ]
        }
        if lower.contains("metta") || lower.contains("loving") || lower.contains("kindness") {
            return [
                .italic("Mettā"),
                .text(" — boundless friendliness. The "),
                .citation(SuttaCite(code: "Snp 1.8", englishTitle: "Karaṇīya Mettā Sutta", suttaID: "snp1.8")),
                .text(" tells us how: just as a mother would protect with her life her own child, her only child, so let one cultivate boundless love towards all beings. Above, below, and across — without obstruction, without hatred."),
            ]
        }
        if lower.contains("emptiness") || lower.contains("form") {
            return [
                .text("In the "),
                .citation(SuttaCite(code: "Heart Sūtra", englishTitle: "Heart of Perfect Wisdom", suttaID: "MH_HEART")),
                .text(", the line everyone knows: "),
                .italic("form is emptiness; emptiness is form"),
                .text(". Not two stages of a process. Not a riddle. The same gesture, seen from inside and from outside.")
            ]
        }
        if lower.contains("koan") || lower.contains("mu") || lower.contains("zen") {
            return [
                .text("There's a kōan that does the work for this. In the "),
                .citation(SuttaCite(code: "Mumonkan · 1", englishTitle: "Joshu's Mu", suttaID: "ZEN_MUMON_1")),
                .text(", a monk asks Joshu, 'Has a dog the Buddha-nature?' Joshu answers, "),
                .italic("Mu"),
                .text(". Not yes, not no. The whole point is not to settle.")
            ]
        }
        // generic fallback uses the tradition's voice
        return [
            .text("This is a question worth sitting with. The tradition you've chosen — "),
            .italic(tradition.name),
            .text(" — would meet it from "),
            .text(tradition.blurb.lowercased()),
            .text(" Try giving it a few breaths before the next thought.")
        ]
    }
}
