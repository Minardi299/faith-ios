import Foundation

@MainActor
protocol UserRepository: AnyObject {
    func load() -> AppUser?
    func save(_ user: AppUser)
    func clear()
}

@MainActor
final class LocalUserRepository: UserRepository {
    private let userKey = "faith.user"
    private let onboardingKey = "faith.onboardingComplete"
    private let defaults = UserDefaults.standard

    func load() -> AppUser? {
        guard let data = defaults.data(forKey: userKey),
              let user = try? JSONDecoder().decode(AppUser.self, from: data) else {
            return nil
        }
        return user
    }

    func save(_ user: AppUser) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: userKey)
        }
    }

    func clear() {
        defaults.removeObject(forKey: userKey)
        defaults.removeObject(forKey: onboardingKey)
    }

}
