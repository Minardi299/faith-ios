import Foundation

/// A single unit of audio playback. The queue holds these; auto-advance pops
/// the head. Built by the `ListenQueueStore.expand(...)` family from
/// `StudyItem` (single or chaptered work) and one-off passages.
struct PlayableItem: Identifiable, Hashable {
    /// Unique within a queue. For single passages this is the passage ID; for
    /// chaptered works this is `<itemID>#<chapterID>` so the same passage can
    /// appear in multiple work contexts without collision.
    let id: String

    /// The canonical passage ID resolvable through `CanonStore`. Required —
    /// every play unit has a passage (real or metadata-only).
    let passageID: String

    /// Display title shown on the listen surface and mini-player.
    let displayTitle: String

    /// Display subtitle: chapter number, queue position, tradition pill, etc.
    let displaySubtitle: String

    /// Tradition for substrate, accent dot, and now-playing artwork.
    let tradition: Tradition

    /// Pre-flight estimate used for the progress ring before AVSpeech actually
    /// starts. Updated to a more accurate value once the source loads.
    let estimatedSeconds: Int

    /// Curriculum context, if any. Used to fire stage-completion events.
    let stageID: String?
    let trackID: String?

    /// Curriculum index display: "Stage 1 · 2 of 5". nil for one-off passages.
    let queueEyebrow: String?
}

/// Reference to a recently-listened item for the Continue Listening hero card.
struct RecentListenRef: Hashable, Codable {
    let trackID: String?
    let stageID: String?
    let itemID: String?
    let passageID: String
    let lastPositionSeconds: Int
    let estimatedSeconds: Int
    let lastListenedAt: Date

    var progressFraction: Double {
        guard estimatedSeconds > 0 else { return 0 }
        return min(1.0, Double(lastPositionSeconds) / Double(estimatedSeconds))
    }
}
