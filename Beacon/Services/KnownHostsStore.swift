import Foundation

/// Manages trusted host key entries in Keychain and in-memory session cache.
///
/// Keychain storage is added in S5; trust-once session cache in S6.
@MainActor
final class KnownHostsStore {
    /// Looks up a stored host key entry for the given host and port.
    func lookup(host: String, port: Int) -> KnownHostEntry? {
        nil
    }

    /// Saves a host key entry to persistent Keychain storage.
    func save(_ entry: KnownHostEntry) {
        // Implemented in S5
    }

    /// Trusts a host key for the current session only (not persisted).
    func trustOnce(_ entry: KnownHostEntry) {
        // Implemented in S6
    }
}
