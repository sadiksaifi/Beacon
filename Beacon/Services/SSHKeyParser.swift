@preconcurrency import Citadel
import CryptoKit
import Foundation

/// Parses SSH private key strings to determine their type, encryption status,
/// and extract key material for storage.
enum SSHKeyParser {

    // MARK: - Result Type

    /// The outcome of parsing an SSH private key string.
    enum ParseResult {
        /// An unencrypted key whose raw bytes are immediately available.
        case unencrypted(privateKeyData: Data, keyType: SSHKeyType, publicKeyData: Data)
        /// An encrypted key that requires a passphrase before its bytes can be read.
        case encrypted(keyType: SSHKeyType, rawKeyString: String)
    }

    // MARK: - Errors

    /// Errors that can occur when parsing or decrypting SSH private keys.
    enum ParseError: LocalizedError {
        /// The string looks like a public key, not a private key.
        case notAPrivateKey
        /// The key format is recognized but not supported.
        case unsupportedFormat(String)
        /// The key type within a supported format is not handled.
        case unsupportedKeyType(String)
        /// The key data is structurally invalid.
        case malformedKey(String)
        /// ECDSA keys in OpenSSH binary format cannot be processed.
        case ecdsaOpenSSHNotSupported
        /// The passphrase was incorrect or decryption otherwise failed.
        case decryptionFailed

        var errorDescription: String? {
            switch self {
            case .notAPrivateKey:
                "The provided text is a public key, not a private key."
            case .unsupportedFormat(let detail):
                detail
            case .unsupportedKeyType(let detail):
                "Unsupported key type: \(detail)"
            case .malformedKey(let detail):
                "Malformed key: \(detail)"
            case .ecdsaOpenSSHNotSupported:
                "ECDSA keys in OpenSSH format are not supported. Please export as PEM format instead."
            case .decryptionFailed:
                "Decryption failed. The passphrase may be incorrect."
            }
        }
    }

    // MARK: - Public API

    /// Parses an SSH private key string and returns its type and key material.
    ///
    /// Encrypted keys are detected but not decrypted — use ``decrypt(keyString:passphrase:)``
    /// to unlock them.
    ///
    /// - Parameter string: The full text of the private key file, including PEM markers.
    /// - Returns: A ``ParseResult`` describing the key.
    /// - Throws: ``ParseError`` if the key cannot be recognized or parsed.
    static func parse(string: String) throws -> ParseResult {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Check for PEM markers
        if trimmed.contains("-----BEGIN") {
            return try parsePEMKey(trimmed)
        }

        // 6. Public key detection
        if trimmed.hasPrefix("ssh-") || trimmed.hasPrefix("ecdsa-") {
            throw ParseError.notAPrivateKey
        }

        // 7. Unrecognized
        throw ParseError.unsupportedFormat("Unrecognized key format")
    }

    /// Decrypts an encrypted SSH private key using the provided passphrase.
    ///
    /// - Parameters:
    ///   - keyString: The full text of the encrypted private key file.
    ///   - passphrase: The passphrase protecting the key.
    /// - Returns: A ``ParseResult/unencrypted(privateKeyData:keyType:publicKeyData:)`` result.
    /// - Throws: ``ParseError/decryptionFailed`` if the passphrase is wrong or decryption fails.
    static func decrypt(keyString: String, passphrase: String) throws -> ParseResult {
        let trimmed = keyString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Detect key type from the binary header
        let keyType = try detectOpenSSHKeyType(from: trimmed)

        do {
            switch keyType {
            case .ed25519:
                let key = try Curve25519.Signing.PrivateKey(
                    sshEd25519: trimmed,
                    decryptionKey: Data(passphrase.utf8)
                )
                return .unencrypted(
                    privateKeyData: key.rawRepresentation,
                    keyType: .ed25519,
                    publicKeyData: key.publicKey.rawRepresentation
                )
            case .rsa:
                let key = try Insecure.RSA.PrivateKey(
                    sshRsa: trimmed,
                    decryptionKey: Data(passphrase.utf8)
                )
                // RSA keys can't round-trip via rawRepresentation; store the full key string.
                _ = key
                return .unencrypted(
                    privateKeyData: Data(trimmed.utf8),
                    keyType: .rsa,
                    publicKeyData: Data()
                )
            case .ecdsaP256:
                throw ParseError.ecdsaOpenSSHNotSupported
            }
        } catch let error as ParseError {
            throw error
        } catch {
            throw ParseError.decryptionFailed
        }
    }

    // MARK: - PEM Routing

    /// Routes a PEM-formatted key string to the appropriate parser.
    private static func parsePEMKey(_ string: String) throws -> ParseResult {
        if string.contains("-----BEGIN OPENSSH PRIVATE KEY-----") {
            return try parseOpenSSHKey(string)
        }

        if string.contains("-----BEGIN EC PRIVATE KEY-----")
            || string.contains("-----BEGIN EC PARAMETERS-----")
        {
            return try parseECDSAPEM(string)
        }

        if string.contains("-----BEGIN RSA PRIVATE KEY-----") {
            throw ParseError.unsupportedFormat(
                "Legacy RSA PEM format is not supported. Please convert to OpenSSH format."
            )
        }

        throw ParseError.unsupportedFormat(
            "Unrecognized PEM key format. Only OpenSSH and ECDSA PEM formats are supported."
        )
    }

    // MARK: - OpenSSH Format

    /// Parses an OpenSSH-format private key, handling both encrypted and unencrypted variants.
    private static func parseOpenSSHKey(_ string: String) throws -> ParseResult {
        let binaryData = try decodeOpenSSHBase64(from: string)

        // Validate magic bytes: "openssh-key-v1\0"
        let magic = "openssh-key-v1\0"
        let magicData = Data(magic.utf8)
        guard binaryData.count >= magicData.count,
              binaryData.prefix(magicData.count) == magicData
        else {
            throw ParseError.malformedKey("Missing OpenSSH magic header")
        }

        var offset = magicData.count

        // Read cipher name
        guard let (cipherName, nextOffset) = readLengthPrefixedString(from: binaryData, at: offset)
        else {
            throw ParseError.malformedKey("Cannot read cipher name")
        }
        offset = nextOffset

        if cipherName != "none" {
            // Encrypted key — detect type from the public key section
            let keyType = try detectKeyTypeFromBinary(binaryData, startingAt: offset)
            return .encrypted(keyType: keyType, rawKeyString: string)
        }

        // Unencrypted key — detect type and delegate to Citadel / CryptoKit
        let keyType = try detectKeyTypeFromBinary(binaryData, startingAt: offset)
        return try parseUnencryptedOpenSSH(string, keyType: keyType)
    }

    /// Decodes the base64 payload between OpenSSH PEM markers.
    private static func decodeOpenSSHBase64(from string: String) throws -> Data {
        let beginMarker = "-----BEGIN OPENSSH PRIVATE KEY-----"
        let endMarker = "-----END OPENSSH PRIVATE KEY-----"

        guard let beginRange = string.range(of: beginMarker),
              let endRange = string.range(of: endMarker)
        else {
            throw ParseError.malformedKey("Missing OpenSSH PEM markers")
        }

        let base64Content = string[beginRange.upperBound..<endRange.lowerBound]
            .replacing("\n", with: "")
            .replacing("\r", with: "")
            .replacing(" ", with: "")

        guard let data = Data(base64Encoded: String(base64Content)) else {
            throw ParseError.malformedKey("Invalid base64 encoding")
        }

        return data
    }

    /// Detects the SSH key type from the binary public key section.
    ///
    /// The layout after cipher name is: kdf name, kdf options, number of keys, then the
    /// public key blob (which starts with a length-prefixed key type string).
    private static func detectKeyTypeFromBinary(
        _ data: Data,
        startingAt offset: Int
    ) throws -> SSHKeyType {
        var pos = offset

        // Skip kdf name
        guard let afterKdf = skipLengthPrefixed(from: data, at: pos) else {
            throw ParseError.malformedKey("Cannot read KDF name")
        }
        pos = afterKdf

        // Skip kdf options
        guard let afterKdfOptions = skipLengthPrefixed(from: data, at: pos) else {
            throw ParseError.malformedKey("Cannot read KDF options")
        }
        pos = afterKdfOptions

        // Read number of keys (4-byte uint32)
        guard pos + 4 <= data.count else {
            throw ParseError.malformedKey("Cannot read number of keys")
        }
        pos += 4

        // Read public key blob length
        guard pos + 4 <= data.count else {
            throw ParseError.malformedKey("Cannot read public key blob length")
        }
        let blobLength = Int(
            UInt32(data[pos]) << 24 | UInt32(data[pos + 1]) << 16
                | UInt32(data[pos + 2]) << 8 | UInt32(data[pos + 3])
        )
        pos += 4

        guard pos + blobLength <= data.count else {
            throw ParseError.malformedKey("Public key blob extends past end of data")
        }

        // First field inside the public key blob is the key type string
        guard let (keyTypeString, _) = readLengthPrefixedString(from: data, at: pos) else {
            throw ParseError.malformedKey("Cannot read key type from public key blob")
        }

        return try mapKeyTypeString(keyTypeString)
    }

    /// Detects the key type from a full OpenSSH PEM key string by parsing its binary header.
    private static func detectOpenSSHKeyType(from string: String) throws -> SSHKeyType {
        let binaryData = try decodeOpenSSHBase64(from: string)

        let magic = "openssh-key-v1\0"
        let magicData = Data(magic.utf8)
        guard binaryData.count >= magicData.count,
              binaryData.prefix(magicData.count) == magicData
        else {
            throw ParseError.malformedKey("Missing OpenSSH magic header")
        }

        var offset = magicData.count

        // Read cipher name
        guard let (_, nextOffset) = readLengthPrefixedString(from: binaryData, at: offset) else {
            throw ParseError.malformedKey("Cannot read cipher name")
        }
        offset = nextOffset

        return try detectKeyTypeFromBinary(binaryData, startingAt: offset)
    }

    /// Maps an SSH key type wire string to the app's ``SSHKeyType`` enum.
    private static func mapKeyTypeString(_ string: String) throws -> SSHKeyType {
        switch string {
        case "ssh-ed25519":
            return .ed25519
        case "ssh-rsa":
            return .rsa
        case "ecdsa-sha2-nistp256":
            throw ParseError.ecdsaOpenSSHNotSupported
        default:
            throw ParseError.unsupportedKeyType(string)
        }
    }

    /// Parses an unencrypted OpenSSH key using Citadel's initializers.
    private static func parseUnencryptedOpenSSH(
        _ string: String,
        keyType: SSHKeyType
    ) throws -> ParseResult {
        switch keyType {
        case .ed25519:
            do {
                let key = try Curve25519.Signing.PrivateKey(sshEd25519: string)
                return .unencrypted(
                    privateKeyData: key.rawRepresentation,
                    keyType: .ed25519,
                    publicKeyData: key.publicKey.rawRepresentation
                )
            } catch {
                throw ParseError.malformedKey("Failed to parse Ed25519 key: \(error.localizedDescription)")
            }
        case .rsa:
            do {
                let key = try Insecure.RSA.PrivateKey(sshRsa: string)
                // RSA keys can't round-trip via rawRepresentation; store the full OpenSSH string.
                _ = key
                return .unencrypted(
                    privateKeyData: Data(string.utf8),
                    keyType: .rsa,
                    publicKeyData: Data()
                )
            } catch {
                throw ParseError.malformedKey("Failed to parse RSA key: \(error.localizedDescription)")
            }
        case .ecdsaP256:
            throw ParseError.ecdsaOpenSSHNotSupported
        }
    }

    // MARK: - ECDSA PEM Format

    /// Parses an ECDSA P-256 key in traditional PEM format using CryptoKit.
    private static func parseECDSAPEM(_ string: String) throws -> ParseResult {
        do {
            let key = try P256.Signing.PrivateKey(pemRepresentation: string)
            return .unencrypted(
                privateKeyData: key.rawRepresentation,
                keyType: .ecdsaP256,
                publicKeyData: key.publicKey.rawRepresentation
            )
        } catch {
            throw ParseError.malformedKey(
                "Failed to parse ECDSA PEM key: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Binary Helpers

    /// Reads a length-prefixed string from OpenSSH binary data at the given offset.
    ///
    /// - Parameters:
    ///   - data: The binary data buffer.
    ///   - offset: The byte offset to start reading from.
    /// - Returns: A tuple of the decoded string and the new offset after reading, or `nil`
    ///   if there is insufficient data.
    private static func readLengthPrefixedString(from data: Data, at offset: Int) -> (String, Int)? {
        guard offset + 4 <= data.count else { return nil }
        let length = Int(
            UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16
                | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
        )
        let stringEnd = offset + 4 + length
        guard stringEnd <= data.count else { return nil }
        let stringData = data[(offset + 4)..<stringEnd]
        guard let string = String(data: stringData, encoding: .utf8) else { return nil }
        return (string, stringEnd)
    }

    /// Skips a length-prefixed field in OpenSSH binary data, returning the new offset.
    ///
    /// - Parameters:
    ///   - data: The binary data buffer.
    ///   - offset: The byte offset to start reading from.
    /// - Returns: The offset immediately past the skipped field, or `nil` if there is
    ///   insufficient data.
    private static func skipLengthPrefixed(from data: Data, at offset: Int) -> Int? {
        guard offset + 4 <= data.count else { return nil }
        let length = Int(
            UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16
                | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
        )
        let end = offset + 4 + length
        guard end <= data.count else { return nil }
        return end
    }
}
