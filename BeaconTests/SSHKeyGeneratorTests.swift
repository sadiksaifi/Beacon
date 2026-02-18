import CryptoKit
import Testing
@testable import Beacon

@Suite("SSH Key Generator")
struct SSHKeyGeneratorTests {
    @Test("Ed25519 generation produces 32-byte private key data")
    func ed25519PrivateKeySize() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ed25519)
        #expect(keyPair.privateKeyData.count == 32)
    }

    @Test("Ed25519 generation produces non-empty public key string starting with ssh-ed25519")
    func ed25519PublicKeyStringPrefix() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ed25519)
        #expect(!keyPair.publicKeyString.isEmpty)
        #expect(keyPair.publicKeyString.hasPrefix("ssh-ed25519 "))
    }

    @Test("Ed25519 generation produces non-empty public key data")
    func ed25519PublicKeyData() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ed25519)
        #expect(!keyPair.publicKeyData.isEmpty)
    }

    @Test("P-256 generation produces 32-byte private key data")
    func p256PrivateKeySize() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ecdsaP256)
        // CryptoKit P256 raw representation is the scalar value (32 bytes)
        // but the full raw representation includes both x and y coordinates for public key
        // The private key rawRepresentation is 32 bytes
        #expect(keyPair.privateKeyData.count == 32)
    }

    @Test("P-256 generation produces non-empty public key string starting with ecdsa-sha2-nistp256")
    func p256PublicKeyStringPrefix() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ecdsaP256)
        #expect(!keyPair.publicKeyString.isEmpty)
        #expect(keyPair.publicKeyString.hasPrefix("ecdsa-sha2-nistp256 "))
    }

    @Test("P-256 generation produces non-empty public key data")
    func p256PublicKeyData() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ecdsaP256)
        #expect(!keyPair.publicKeyData.isEmpty)
    }

    @Test("RSA generation throws unsupportedKeyType")
    func rsaThrowsUnsupported() {
        #expect {
            try SSHKeyGenerator.generate(type: .rsa)
        } throws: { error in
            error is SSHKeyGenerationError
        }
    }

    @Test("Two Ed25519 keys produce different key data")
    func ed25519RandomnessCheck() throws {
        let keyPair1 = try SSHKeyGenerator.generate(type: .ed25519)
        let keyPair2 = try SSHKeyGenerator.generate(type: .ed25519)
        #expect(keyPair1.privateKeyData != keyPair2.privateKeyData)
    }
}
