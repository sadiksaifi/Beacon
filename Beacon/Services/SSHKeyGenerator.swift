import CryptoKit
import Foundation

/// Errors that can occur during SSH key generation.
enum SSHKeyGenerationError: LocalizedError {
    /// The requested key type cannot be generated on-device (e.g. RSA).
    case unsupportedKeyType

    var errorDescription: String? {
        switch self {
        case .unsupportedKeyType:
            "This key type cannot be generated on-device."
        }
    }
}

/// Generates SSH key pairs using platform cryptography.
///
/// Ed25519 and ECDSA P-256 keys are generated via Apple CryptoKit.
/// RSA key generation is not supported; RSA keys can only be imported.
enum SSHKeyGenerator {
    /// The result of generating an SSH key pair.
    struct KeyPair {
        /// The private key bytes suitable for secure storage.
        let privateKeyData: Data
        /// The OpenSSH authorized_keys formatted public key string.
        let publicKeyString: String
        /// The raw public key bytes.
        let publicKeyData: Data
    }

    /// Generates a new SSH key pair of the specified type.
    ///
    /// - Parameter type: The cryptographic algorithm to use.
    /// - Returns: A ``KeyPair`` containing the private key data, formatted
    ///   public key string, and raw public key bytes.
    /// - Throws: ``SSHKeyGenerationError/unsupportedKeyType`` if the key type
    ///   cannot be generated on-device.
    static func generate(type: SSHKeyType) throws -> KeyPair {
        switch type {
        case .ed25519:
            return generateEd25519()
        case .ecdsaP256:
            return generateECDSAP256()
        case .rsa:
            throw SSHKeyGenerationError.unsupportedKeyType
        }
    }

    // MARK: - Private Helpers

    private static func generateEd25519() -> KeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation

        let publicKeyString = SSHPublicKeyFormatter.format(
            publicKeyData: publicKeyData,
            keyType: .ed25519
        )

        return KeyPair(
            privateKeyData: Data(privateKey.rawRepresentation),
            publicKeyString: publicKeyString,
            publicKeyData: Data(publicKeyData)
        )
    }

    private static func generateECDSAP256() -> KeyPair {
        let privateKey = P256.Signing.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation

        let publicKeyString = SSHPublicKeyFormatter.format(
            publicKeyData: publicKeyData,
            keyType: .ecdsaP256
        )

        return KeyPair(
            privateKeyData: Data(privateKey.rawRepresentation),
            publicKeyString: publicKeyString,
            publicKeyData: Data(publicKeyData)
        )
    }
}
