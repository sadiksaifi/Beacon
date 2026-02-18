import CryptoKit
import Foundation
import Testing
@testable import Beacon

@Suite("SSH Key Auth Integration", .tags(.integration))
struct SSHKeyAuthTests {
    private let host = "localhost"
    private let port = 2222

    /// TCP probe to check if the Docker harness is reachable.
    private func isHarnessAvailable() async -> Bool {
        await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(
                with: URL(string: "http://\(host):\(port)")!
            ) { _, response, error in
                if error == nil {
                    continuation.resume(returning: true)
                    return
                }

                let nsError = error! as NSError
                if nsError.domain == NSURLErrorDomain
                    && nsError.code != NSURLErrorCannotConnectToHost
                    && nsError.code != NSURLErrorTimedOut
                    && nsError.code != NSURLErrorNotConnectedToInternet
                {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
            task.resume()
        }
    }

    @Test("Ed25519 key round-trips through raw representation")
    func ed25519RoundTrip() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ed25519)

        // Reconstruct from stored data (as SSHConnectionService would)
        let reconstructed = try Curve25519.Signing.PrivateKey(
            rawRepresentation: keyPair.privateKeyData
        )

        // Verify signing works
        let message = Data("test message".utf8)
        let signature = try reconstructed.signature(for: message)
        #expect(reconstructed.publicKey.isValidSignature(signature, for: message))
    }

    @Test("P-256 key round-trips through raw representation")
    func p256RoundTrip() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ecdsaP256)

        // Reconstruct from stored data
        let reconstructed = try P256.Signing.PrivateKey(
            rawRepresentation: keyPair.privateKeyData
        )

        // Verify signing works
        let message = Data("test message".utf8)
        let signature = try reconstructed.signature(for: message)
        #expect(reconstructed.publicKey.isValidSignature(signature, for: message))
    }

    @Test("Ed25519 public key has valid OpenSSH format")
    func ed25519PublicKeyFormat() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ed25519)

        #expect(keyPair.publicKeyString.hasPrefix("ssh-ed25519 "))

        // Extract base64 part and verify it's valid
        let parts = keyPair.publicKeyString.split(separator: " ")
        #expect(parts.count >= 2)

        let base64Part = String(parts[1])
        let decoded = Data(base64Encoded: base64Part)
        #expect(decoded != nil)
        #expect((decoded?.count ?? 0) > 0)
    }

    @Test("P-256 public key has valid OpenSSH format")
    func p256PublicKeyFormat() throws {
        let keyPair = try SSHKeyGenerator.generate(type: .ecdsaP256)

        #expect(keyPair.publicKeyString.hasPrefix("ecdsa-sha2-nistp256 "))

        // Extract base64 part and verify it's valid
        let parts = keyPair.publicKeyString.split(separator: " ")
        #expect(parts.count >= 2)

        let base64Part = String(parts[1])
        let decoded = Data(base64Encoded: base64Part)
        #expect(decoded != nil)
        #expect((decoded?.count ?? 0) > 0)
    }

    @Test("Key reconstruction from raw data produces valid CryptoKit keys")
    func keyReconstructionProducesValidKeys() throws {
        // Ed25519
        let ed25519Pair = try SSHKeyGenerator.generate(type: .ed25519)
        let ed25519Key = try Curve25519.Signing.PrivateKey(
            rawRepresentation: ed25519Pair.privateKeyData
        )
        #expect(ed25519Key.publicKey.rawRepresentation == ed25519Pair.publicKeyData)

        // P-256
        let p256Pair = try SSHKeyGenerator.generate(type: .ecdsaP256)
        let p256Key = try P256.Signing.PrivateKey(
            rawRepresentation: p256Pair.privateKeyData
        )
        #expect(p256Key.publicKey.rawRepresentation == p256Pair.publicKeyData)
    }

    @Test("Auth failure with key context gives key-specific message")
    func keyAuthFailureMessage() {
        // AuthenticationFailed is a Citadel type; simulate via SSHErrorMapper with context
        // Use a generic auth-like error string to trigger the fallback matching
        let error = NSError(
            domain: "TestDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "authentication failed"]
        )
        let message = SSHErrorMapper.message(for: error, context: .key)
        #expect(
            message
                == "Key authentication failed — the server may not have your public key in authorized_keys."
        )
    }

    @Test("Auth failure with password context gives generic message")
    func passwordAuthFailureMessage() {
        let error = NSError(
            domain: "TestDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "authentication failed"]
        )
        let message = SSHErrorMapper.message(for: error, context: .password)
        #expect(message == "Authentication failed")
    }
}
