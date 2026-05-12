import Foundation
import SwiftUI
import SwiftData
import Combine

enum AccountDeletionError: LocalizedError {
    case wipeFailed

    var errorDescription: String? {
        switch self {
        case .wipeFailed:
            return "Some data could not be deleted. Please try again or check Settings."
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    // dependencies
    let auth: AuthService
    let users: UserRepository
    let llm: LLMRuntime
    let modelContext: ModelContext

    // observed state
    @Published var user: AppUser

    @Published var streakDays: Int = 0
    @Published var todayPracticed: PracticeMark? = nil
    @Published var minutesSatToday: Int = 0
    @Published var lastDeletionError: Error? = nil

    /// Production runtime: real Foundation Models when available, retrieval-
    /// only fallback otherwise (Simulator and pre-iOS-26 devices). Mock stays
    /// available for `#Preview` blocks that don't need real RAG.
    static func defaultLLM() -> LLMRuntime { FoundationModelsRuntime() }

    init(modelContext: ModelContext,
         auth: AuthService? = nil,
         users: UserRepository? = nil,
         llm: LLMRuntime? = nil) {
        let resolvedAuth = auth ?? AppleAuthService()
        let resolvedUsers = users ?? LocalUserRepository()
        let resolvedLLM = llm ?? Self.defaultLLM()
        self.modelContext = modelContext
        self.auth = resolvedAuth
        self.users = resolvedUsers
        self.llm = resolvedLLM
        if let saved = resolvedUsers.load() {
            self.user = saved
        } else {
            self.user = AppUser.sample
        }

        refreshDerivedStats()
    }

    // MARK: - Mutations

    func signOut() {
        auth.signOut()
        users.clear()
        user = .sample
    }

    func deleteAccount() {
        lastDeletionError = nil
        let savedOK = AccountDeletion.wipe(modelContext: modelContext, users: users)
        auth.signOut()
        if savedOK {
            user = .sample
            // Reset cached streak/minutes immediately so the home view
            // doesn't momentarily show stale values after sign-out.
            refreshDerivedStats()
        } else {
            // SwiftData wipe failed — surface so Profile can alert the user.
            lastDeletionError = AccountDeletionError.wipeFailed
        }
    }

    func markPracticed(_ mark: PracticeMark) {
        todayPracticed = mark
    }

    // MARK: - Derived stats

    func refreshDerivedStats() {
        minutesSatToday = PracticeQueries.minutesSatToday(in: modelContext)
        streakDays      = PracticeQueries.currentStreak(in: modelContext)
    }
}
