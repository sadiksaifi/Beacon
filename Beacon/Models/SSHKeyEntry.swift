import Foundation

/// Metadata for a stored SSH key pair. The private key lives in the Keychain;
/// this struct holds everything else and is persisted as JSON in UserDefaults.
struct SSHKeyEntry: Codable, Identifiable, Hashable {
    /// Stable identifier, also used to derive the Keychain item key.
    var id: UUID = UUID()

    /// User-facing name for the key (e.g. "Work laptop").
    var label: String

    /// The cryptographic algorithm of the key pair.
    var keyType: SSHKeyType

    /// Raw public key data (algorithm-specific encoding).
    var publicKey: Data

    /// When the key pair was generated or imported.
    var createdAt: Date

    /// Identifier used to store and retrieve the private key in the Keychain.
    var keychainID: String {
        "key:\(id.uuidString)"
    }
}
