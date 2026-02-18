import Foundation

/// A trusted host key entry persisted in Keychain or held in memory.
struct KnownHostEntry: Codable {
    /// The hostname of the server.
    let hostname: String

    /// The port of the server.
    let port: Int

    /// The key algorithm identifier (e.g. "ssh-ed25519").
    let algorithm: String

    /// The SHA-256 fingerprint in "SHA256:{base64}" format.
    let fingerprint: String

    /// When the user first trusted this host key.
    let trustedAt: Date
}
