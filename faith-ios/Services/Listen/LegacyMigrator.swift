import Foundation

/// One-shot migration: copy progress from the legacy `PathwayProgressStore`
/// into the new `ListenProgressStore` so users who marked suttas read in the
/// old pathway flow see those items reflected in the listen progress arc.
///
/// Idempotent — runs at most once per device, gated by a UserDefaults key.
@MainActor
enum LegacyMigrator {

    private static let migratedKey = "listenProgress.migratedFromPathway.v1"

    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        let pathway = PathwayProgressStore.shared
        let listen = ListenProgressStore.shared
        var migrated = 0
        for (_, progress) in pathway.byPathway {
            for suttaID in progress.readSuttaIDs {
                if !listen.isCompleted(passageID: suttaID) {
                    listen.markCompleted(passageID: suttaID)
                    migrated += 1
                }
            }
        }
        listen.saveImmediately()
        UserDefaults.standard.set(true, forKey: migratedKey)
        if migrated > 0 {
            print("✅ LegacyMigrator: migrated \(migrated) read marks from PathwayProgressStore")
        }
    }
}
