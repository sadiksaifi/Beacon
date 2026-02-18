import CryptoKit
import Foundation

/// Formats raw public key data into OpenSSH authorized_keys format.
enum SSHPublicKeyFormatter {
    /// Builds an OpenSSH authorized_keys line from raw public key bytes.
    ///
    /// The wire format follows RFC 4253: each field is preceded by a 4-byte
    /// big-endian length prefix. The resulting bytes are Base64-encoded and
    /// returned alongside the key type prefix and optional comment.
    ///
    /// - Parameters:
    ///   - publicKeyData: The raw public key bytes (32 bytes for Ed25519,
    ///     32 bytes for ECDSA P-256).
    ///   - keyType: The SSH key algorithm.
    ///   - comment: An optional comment appended to the line.
    /// - Returns: A string in authorized_keys format, e.g.
    ///   `ssh-ed25519 AAAA... user@host`.
    static func format(publicKeyData: Data, keyType: SSHKeyType, comment: String = "") -> String {
        var wireFormat = Data()

        switch keyType {
        case .ed25519:
            appendLengthPrefixed(keyType.sshPrefix, to: &wireFormat)
            appendLengthPrefixed(publicKeyData, to: &wireFormat)

        case .ecdsaP256:
            // Reconstruct the uncompressed point (65 bytes) from the raw
            // representation (32 bytes) via CryptoKit.
            let publicKey = try? P256.Signing.PublicKey(rawRepresentation: publicKeyData)
            let uncompressedPoint = publicKey?.x963Representation ?? Data()

            appendLengthPrefixed(keyType.sshPrefix, to: &wireFormat)
            appendLengthPrefixed("nistp256", to: &wireFormat)
            appendLengthPrefixed(uncompressedPoint, to: &wireFormat)

        case .rsa:
            // RSA keys are import-only; formatting is not supported.
            return ""
        }

        let base64 = wireFormat.base64EncodedString()
        let suffix = comment.isEmpty ? "" : " \(comment)"
        return "\(keyType.sshPrefix) \(base64)\(suffix)"
    }

    // MARK: - Private Helpers

    /// Appends a 4-byte big-endian length prefix followed by the UTF-8 bytes
    /// of the given string.
    private static func appendLengthPrefixed(_ string: String, to data: inout Data) {
        let bytes = Data(string.utf8)
        appendLengthPrefixed(bytes, to: &data)
    }

    /// Appends a 4-byte big-endian length prefix followed by the raw bytes.
    private static func appendLengthPrefixed(_ bytes: Data, to data: inout Data) {
        var length = UInt32(bytes.count).bigEndian
        data.append(Data(bytes: &length, count: 4))
        data.append(bytes)
    }
}
