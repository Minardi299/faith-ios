import Foundation
import SwiftData
import os

private let log = Logger(subsystem: "com.faith.app", category: "persistence")

@MainActor
enum PersistenceContainer {
    static let schema = Schema([
        JournalEntry.self,
        StoredChatThread.self,
        StoredChatMessage.self,
        Anniversary.self,
        PracticeRecord.self,
        DayCompletion.self
    ])

    static let shared: ModelContainer = {
        // SwiftData's default store URL is `Library/Application Support/default.store`,
        // but iOS does not create `Application Support/` on first launch. If we let
        // SwiftData discover this the hard way, Core Data dumps a screenful of
        // `errno 2` warnings before recovering. Pre-create the directory and pass
        // an explicit URL so the first launch is silent.
        let storeURL = applicationSupportStoreURL()
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If a migration fails, fall back to in-memory so the app still launches.
            log.error("ModelContainer init failed: \(error.localizedDescription, privacy: .private). Falling back to in-memory.")
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [inMemory])
        }
    }()

    /// Resolves `Library/Application Support/default.store`, creating the parent
    /// directory if missing. Mirrors what SwiftData would pick by default but
    /// avoids the noisy first-launch error log.
    private static func applicationSupportStoreURL() -> URL {
        let fm = FileManager.default
        let dir: URL
        do {
            dir = try fm.url(for: .applicationSupportDirectory,
                             in: .userDomainMask,
                             appropriateFor: nil,
                             create: true)
        } catch {
            // Last-resort fallback: Documents/ always exists in an iOS app sandbox.
            log.warning("Could not resolve Application Support directory: \(error.localizedDescription, privacy: .private). Falling back to Documents.")
            return fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("default.store")
        }
        // `create: true` above creates the directory if it doesn't exist, but
        // belt-and-suspenders: ensure it exists before handing the URL to SwiftData.
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("default.store")
    }
}
