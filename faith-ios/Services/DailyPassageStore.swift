import Foundation
import Observation

/// Picks the day's reading from `CanonStore.coreReads()` deterministically by
/// epoch-day index. Replaces faith-ios's `VerseStore` daily-verse role.
@MainActor
@Observable
final class DailyPassageStore {
    private let canon: CanonStore

    init(canon: CanonStore = .shared) {
        self.canon = canon
    }

    /// Cached pool of cross-tradition foundation reads. Refreshes when the
    /// canon load completes.
    private var pool: [SuttaPassage] {
        let reads = canon.coreReads()
        return reads.isEmpty ? canon.entries : reads
    }

    /// Returns the passage for the given date. Same date → same passage.
    func passage(for date: Date = .now) -> SuttaPassage? {
        let pool = pool
        guard !pool.isEmpty else { return nil }
        let day = epochDay(for: date)
        let idx = ((day % pool.count) + pool.count) % pool.count
        return pool[idx]
    }

    private func epochDay(for date: Date) -> Int {
        let day = Calendar.current.startOfDay(for: date)
        let epoch = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 0))
        return Calendar.current.dateComponents([.day], from: epoch, to: day).day ?? 0
    }
}
