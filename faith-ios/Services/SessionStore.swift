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
    @Published var phase: AppPhase

    @Published var streakDays: Int = 0
    @Published var todayPracticed: PracticeMark? = nil
    @Published var minutesSatToday: Int = 0

    enum AppPhase: Equatable {
        case splash
        case onboarding
        case main
    }

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
        self.phase = resolvedUsers.hasCompletedOnboarding ? .main : .splash

        refreshDerivedStats()
    }

    // MARK: - Mutations

    func setTradition(_ t: Tradition) {
        user.tradition = t
        users.save(user)
    }

    func completeOnboarding(with user: AppUser) {
        self.user = user
        users.save(user)
        users.hasCompletedOnboarding = true
        self.phase = .main
    }

    func advanceFromSplash() {
        phase = users.hasCompletedOnboarding ? .main : .onboarding
    }

    func resetForDev() {
        users.clear()
        auth.signOut()
        user = .sample
        phase = .splash
    }

    func signOut() {
        auth.signOut()
        users.clear()
        user = .sample
        phase = .splash
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
