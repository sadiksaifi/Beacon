import Foundation

/// Describes a host key presented during an SSH connection attempt.
struct HostKeyChallenge: Identifiable {
    let id = UUID()

    /// The hostname being connected to.
    let hostname: String

    /// The port being connected to.
    let port: Int

    /// The key algorithm display name (e.g. "Ed25519", "ECDSA").
    let keyType: String

    /// The SHA-256 fingerprint in "SHA256:{base64}" format.
    let fingerprint: String
}
