import Foundation
import Security

/// CRUD interface for SSH passwords stored in the iOS Keychain.
///
/// Each password is keyed by `connection:{UUID}` under the service
/// `com.beacon.ssh`. Retrieval requires biometric or passcode verification
/// via `SecAccessControl` with `.userPresence`.
enum KeychainService {
    private static let serviceName = "com.beacon.ssh"

    /// Stores a password in the Keychain for the given connection ID.
    ///
    /// If a password already exists for this connection, it is updated.
    static func store(password: String, forConnectionID connectionID: UUID) {
        guard let data = password.data(using: .utf8) else { return }

        let account = accountKey(for: connectionID)

        // Create access control requiring biometric or passcode
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            nil
        ) else { return }

        // Try to update an existing item first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl,
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // No existing item — add a new one
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessControl as String: accessControl,
                kSecAttrSynchronizable as String: false,
            ]

            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    /// Retrieves a stored password for the given connection ID.
    ///
    /// Returns `nil` if no password is stored or if the user cancels
    /// biometric/passcode verification.
    ///
    /// Runs on a detached task to avoid blocking the MainActor during
    /// the biometric prompt.
    static func retrieve(forConnectionID connectionID: UUID) async -> String? {
        let account = accountKey(for: connectionID)

        return await Task.detached {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess, let data = result as? Data else {
                return nil
            }

            return String(data: data, encoding: .utf8)
        }.value
    }

    /// Deletes a stored password for the given connection ID.
    static func delete(forConnectionID connectionID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountKey(for: connectionID),
        ]

        SecItemDelete(query as CFDictionary)
    }

    private static func accountKey(for connectionID: UUID) -> String {
        "password:\(connectionID.uuidString)"
    }
}
