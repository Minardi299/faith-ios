import Foundation
import SwiftData

@MainActor
enum ChatStore {
    /// Returns the most recent thread, creating one if none exists.
    /// New threads write traditionRaw = "secular" — the field is kept in
    /// the schema for compatibility but no longer scopes anything.
    static func currentThread(in context: ModelContext) -> StoredChatThread {
        let descriptor = FetchDescriptor<StoredChatThread>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let new = StoredChatThread(traditionRaw: "secular")
        context.insert(new)
        try? context.save()
        return new
    }

    static func append(_ message: ChatMessage, to thread: StoredChatThread, in context: ModelContext) {
        let stored = StoredChatMessage.from(message, in: thread)
        context.insert(stored)
        try? context.save()
    }

    static func sortedMessages(_ thread: StoredChatThread) -> [StoredChatMessage] {
        thread.messages.sorted { $0.timestamp < $1.timestamp }
    }

    /// Wipe every message in the thread but keep the thread shell so callers
    /// don't have to re-fetch.
    static func clear(_ thread: StoredChatThread, in context: ModelContext) {
        for msg in thread.messages {
            context.delete(msg)
        }
        thread.messages.removeAll()
        try? context.save()
    }
}
