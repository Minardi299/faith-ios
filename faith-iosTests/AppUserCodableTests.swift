import Testing
import Foundation
@testable import faith_ios

@MainActor
struct AppUserCodableTests {
    /// Legacy AppUser blobs in UserDefaults still contain a `tradition`
    /// field — decoding must ignore it instead of failing, so users
    /// upgrading don't lose their saved preferences.
    @Test
    func decodesLegacyBlobWithTraditionField() throws {
        let legacyJSON = """
        {
          "id": "local",
          "displayName": "Hoang",
          "tradition": "theravada",
          "experience": "someSitting",
          "dailyMinutes": 10,
          "topics": [],
          "notificationsAllowed": true
        }
        """
        let data = Data(legacyJSON.utf8)
        let user = try JSONDecoder().decode(AppUser.self, from: data)
        #expect(user.id == "local")
        #expect(user.displayName == "Hoang")
        #expect(user.dailyMinutes == 10)
        #expect(user.notificationsAllowed == true)
    }

    /// Round-trips a fresh-installed user (without tradition) through
    /// encode/decode without loss.
    @Test
    func roundTripsFreshUser() throws {
        let original = AppUser.sample
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppUser.self, from: encoded)
        #expect(decoded == original)
    }
}
