import Foundation
import Security
import AuthenticationServices

@MainActor
protocol AuthService: AnyObject {
    var isSignedIn: Bool { get }
    var appleUserID: String? { get }
    func handleAppleAuthorization(_ authorization: ASAuthorization) -> AppleSignInResult?
    func continueWithoutAccount()
    func signOut()
}

struct AppleSignInResult {
    let userID: String
    let givenName: String?
    let familyName: String?
    let email: String?
}

@MainActor
final class AppleAuthService: AuthService {
    private let keychainKey = "faith.appleUserID"

    var isSignedIn: Bool { appleUserID != nil || anonymous }
    private(set) var anonymous: Bool = false

    var appleUserID: String? {
        Keychain.read(key: keychainKey)
    }

    func handleAppleAuthorization(_ authorization: ASAuthorization) -> AppleSignInResult? {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return nil
        }
        let userID = credential.user
        Keychain.write(key: keychainKey, value: userID)
        let email = credential.email
        let givenName = credential.fullName?.givenName
        let familyName = credential.fullName?.familyName
        return AppleSignInResult(userID: userID,
                                 givenName: givenName,
                                 familyName: familyName,
                                 email: email)
    }

    func continueWithoutAccount() {
        anonymous = true
    }

    func signOut() {
        Keychain.delete(key: keychainKey)
        anonymous = false
    }
}

@MainActor
final class MockAuthService: AuthService {
    private(set) var isSignedIn: Bool = false
    var appleUserID: String? = nil

    func handleAppleAuthorization(_ authorization: ASAuthorization) -> AppleSignInResult? {
        isSignedIn = true
        return AppleSignInResult(userID: "mock", givenName: nil, familyName: nil, email: nil)
    }

    func continueWithoutAccount() {
        isSignedIn = true
    }

    func signOut() {
        isSignedIn = false
    }
}

/// Tiny keychain wrapper for the Apple stable user ID. Plain-text Strings only.
enum Keychain {
    static func write(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
