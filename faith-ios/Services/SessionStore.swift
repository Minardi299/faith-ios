import Foundation
import SwiftUI
import SwiftData
import Combine

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
        let savedOK = AccountDeletion.wipe(modelContext: modelContext, users: users)
        auth.signOut()
        if savedOK {
            user = .sample
            // Reset cached streak/minutes here but not in signOut() — on normal
            // sign-out the numbers refresh on next view appearance; on deletion
            // we want immediate zero so the splash → onboarding flow doesn't
            // momentarily show stale values.
            refreshDerivedStats()
        }
        // TODO: if savedOK == false, surface a UI alert so the user knows
        // deletion was incomplete and can retry. The session remains signed-out
        // (Apple credential revoked) but the phase is not advanced.
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
