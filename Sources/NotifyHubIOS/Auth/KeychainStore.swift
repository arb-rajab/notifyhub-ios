import Foundation
import Security

/// A thin wrapper around the Keychain Services API for storing the single
/// JWT access token notifyhub issues (ADR-003 - no refresh token, no
/// server-side session, so there is exactly one secret to persist here).
/// Not a general-purpose Keychain library on purpose - this app has one
/// secret to store.
struct KeychainStore {
    private let service: String
    private let account = "notifyhub.accessToken"

    init(service: String = "com.notifyhub.ios") {
        self.service = service
    }

    func save(token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Overwrite any existing item rather than erroring on duplicate.
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status: status)
        }
    }

    func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: Error, LocalizedError {
        case unhandled(status: OSStatus)

        var errorDescription: String? {
            switch self {
            case .unhandled(let status):
                return "Keychain operation failed with status \(status)."
            }
        }
    }
}
