import Foundation
import Security

/// Manages SSH key pair metadata and private key storage.
///
/// Public key metadata (label, type, creation date) is persisted as JSON in
/// UserDefaults so the key list can be displayed without triggering biometric
/// authentication. Private key bytes are stored in the Keychain with
/// `.userPresence` access control, requiring biometric or passcode verification
/// on retrieval.
@MainActor @Observable
final class SSHKeyStore {
    // MARK: - Observable State

    /// The current set of stored SSH key entries.
    private(set) var entries: [SSHKeyEntry] = []

    // MARK: - Constants

    private static let serviceName = "com.beacon.ssh"
    private static let userDefaultsKey = "com.beacon.ssh.keyEntries"

    // MARK: - Init

    init() {
        loadEntries()
    }

    // MARK: - Save

    /// Stores a private key in the Keychain and persists the entry metadata.
    ///
    /// Uses an upsert pattern: attempts `SecItemUpdate` first, falling back to
    /// `SecItemAdd` when no existing item is found.
    func save(privateKey: Data, entry: SSHKeyEntry) {
        let account = entry.keychainID

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
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: account,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: privateKey,
            kSecAttrAccessControl as String: accessControl,
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // No existing item — add a new one
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.serviceName,
                kSecAttrAccount as String: account,
                kSecValueData as String: privateKey,
                kSecAttrAccessControl as String: accessControl,
                kSecAttrSynchronizable as String: false,
            ]

            SecItemAdd(addQuery as CFDictionary, nil)
        }

        // Update the in-memory entries array
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }

        persistEntries()
    }

    // MARK: - Retrieve

    /// Retrieves the private key bytes from the Keychain for the given entry.
    ///
    /// Returns `nil` if no key is stored or if the user cancels biometric/passcode
    /// verification. Runs on a detached task to avoid blocking the MainActor
    /// during the biometric prompt.
    func retrieve(keychainID: String) async -> Data? {
        let service = Self.serviceName

        return await Task.detached {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: keychainID,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess, let data = result as? Data else {
                return nil
            }

            return data
        }.value
    }

    // MARK: - Delete

    /// Removes the SSH key entry and its private key from both storage locations.
    func delete(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }

        // Remove from in-memory array
        entries.removeAll { $0.id == id }

        // Persist updated entries to UserDefaults
        persistEntries()

        // Delete private key from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: entry.keychainID,
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Load

    /// Loads SSH key entry metadata from UserDefaults.
    func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey) else {
            entries = []
            return
        }

        do {
            entries = try JSONDecoder().decode([SSHKeyEntry].self, from: data)
        } catch {
            entries = []
        }
    }

    // MARK: - Private

    /// Persists the current entries array to UserDefaults as JSON.
    private func persistEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}
