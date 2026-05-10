import Foundation
import SwiftData

@MainActor
enum AccountDeletion {
    /// Wipes everything user-owned locally: SwiftData stores, UserDefaults
    /// (incl. App Group), and behavioral-data singletons. Returns `true` if
    /// the SwiftData save succeeded; `false` if it failed (data may remain).
    ///
    /// The caller is expected to also call `auth.signOut()` after this
    /// returns — signOut() owns keychain cleanup (faith.appleUserID).
    @discardableResult
    static func wipe(modelContext: ModelContext, users: UserRepository) -> Bool {
        // 1. SwiftData — delete every record of every user-owned model.
        //    StoredChatThread.messages has deleteRule: .cascade, so deleting
        //    threads alone removes all child messages; no explicit message
        //    delete is needed.
        deleteAll(of: DayCompletion.self, in: modelContext)
        deleteAll(of: Anniversary.self, in: modelContext)
        deleteAll(of: JournalEntry.self, in: modelContext)
        deleteAll(of: PracticeRecord.self, in: modelContext)
        deleteAll(of: StoredChatThread.self, in: modelContext)

        let savedOK: Bool
        do {
            try modelContext.save()
            savedOK = true
        } catch {
            print("⚠️ AccountDeletion: modelContext.save() failed — \(error)")
            savedOK = false
        }

        // 2. UserDefaults — UserRepository keys (user profile, onboarding flag, etc.)
        users.clear()

        // 3. App Group UserDefaults
        if let group = UserDefaults(suiteName: "group.com.faith.app") {
            for key in group.dictionaryRepresentation().keys {
                group.removeObject(forKey: key)
            }
        }

        // 4. UserDefaults.standard — user-behavioral data outside UserRepository.
        //    Both calls clear in-memory @Published state AND remove the backing keys.
        ListenProgressStore.shared.reset()
        PathwayProgressStore.shared.reset()
        // LegacyMigrator sentinel — no in-memory state, key only.
        UserDefaults.standard.removeObject(forKey: "listenProgress.migratedFromPathway.v1")

        return savedOK
    }

    private static func deleteAll<T: PersistentModel>(of type: T.Type, in ctx: ModelContext) {
        do {
            let items = try ctx.fetch(FetchDescriptor<T>())
            items.forEach { ctx.delete($0) }
        } catch {
            print("⚠️ AccountDeletion: failed to fetch \(T.self) — \(error)")
        }
    }
}
