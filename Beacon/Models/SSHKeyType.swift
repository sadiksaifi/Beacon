import Foundation

/// The cryptographic algorithm of an SSH key pair.
enum SSHKeyType: String, Codable, CaseIterable, Identifiable {
    case ed25519
    case ecdsaP256
    case rsa

    var id: Self { self }

    /// Human-readable name for display in the UI.
    var displayName: String {
        switch self {
        case .ed25519: "Ed25519"
        case .ecdsaP256: "ECDSA P-256"
        case .rsa: "RSA"
        }
    }

    /// Whether the app can generate key pairs of this type on-device.
    var supportsGeneration: Bool {
        switch self {
        case .ed25519, .ecdsaP256: true
        case .rsa: false
        }
    }

    /// The prefix used in authorized_keys and known_hosts files.
    var sshPrefix: String {
        switch self {
        case .ed25519: "ssh-ed25519"
        case .ecdsaP256: "ecdsa-sha2-nistp256"
        case .rsa: "ssh-rsa"
        }
    }
}
