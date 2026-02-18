import Foundation
import Security

/// Manages trusted host key entries in Keychain and in-memory session cache.
///
/// Each entry is keyed by `knownhost:{host}:{port}` under the service
/// `com.beacon.ssh`. Entries are JSON-encoded `KnownHostEntry` values.
@MainActor
final class KnownHostsStore {
    private static let serviceName = "com.beacon.ssh"

    // MARK: - Lookup

    /// Looks up a stored host key entry for the given host and port.
    func lookup(host: String, port: Int) -> KnownHostEntry? {
        keychainLookup(host: host, port: port)
    }

    // MARK: - Save

    /// Saves a host key entry to persistent Keychain storage.
    ///
    /// Uses upsert: tries `SecItemUpdate` first, falls back to `SecItemAdd`.
    func save(_ entry: KnownHostEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }

        let account = Self.accountKey(host: entry.hostname, port: entry.port)

        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(
            updateQuery as CFDictionary,
            updateAttributes as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.serviceName,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
                kSecAttrSynchronizable as String: false,
            ]

            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    // MARK: - Replace

    /// Replaces an existing host key entry (delete + save).
    func replace(host: String, port: Int, with entry: KnownHostEntry) {
        delete(host: host, port: port)
        save(entry)
    }

    // MARK: - Delete

    /// Deletes a stored host key entry for the given host and port.
    func delete(host: String, port: Int) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountKey(host: host, port: port),
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Trust Once

    /// Trusts a host key for the current session only (not persisted).
    func trustOnce(_ entry: KnownHostEntry) {
        // Implemented in S6
    }

    // MARK: - Private

    private func keychainLookup(host: String, port: Int) -> KnownHostEntry? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountKey(host: host, port: port),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
            let data = result as? Data,
            let entry = try? JSONDecoder().decode(KnownHostEntry.self, from: data)
        else {
            return nil
        }

        return entry
    }

    private static func accountKey(host: String, port: Int) -> String {
        "knownhost:\(host):\(port)"
    }
}
