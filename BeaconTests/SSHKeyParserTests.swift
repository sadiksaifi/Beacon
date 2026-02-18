import Testing
@testable import Beacon

@Suite("SSH Key Parser")
struct SSHKeyParserTests {
    @Test("Public key string throws notAPrivateKey")
    func publicKeyStringThrows() {
        #expect {
            try SSHKeyParser.parse(string: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKey user@host")
        } throws: { error in
            guard let parseError = error as? SSHKeyParser.ParseError,
                  case .notAPrivateKey = parseError
            else {
                return false
            }
            return true
        }
    }

    @Test("Empty string throws unsupportedFormat")
    func emptyStringThrows() {
        #expect {
            try SSHKeyParser.parse(string: "")
        } throws: { error in
            guard let parseError = error as? SSHKeyParser.ParseError,
                  case .unsupportedFormat = parseError
            else {
                return false
            }
            return true
        }
    }

    @Test("Random text throws unsupportedFormat")
    func randomTextThrows() {
        #expect {
            try SSHKeyParser.parse(string: "this is not a key at all")
        } throws: { error in
            guard let parseError = error as? SSHKeyParser.ParseError,
                  case .unsupportedFormat = parseError
            else {
                return false
            }
            return true
        }
    }

    @Test("Legacy RSA PEM throws unsupportedFormat with conversion message")
    func legacyRSAPEMThrows() {
        let rsaPEM = """
        -----BEGIN RSA PRIVATE KEY-----
        MIIEpAIBAAKCAQEA0Z3VS5JJcds3xfn/ygWyF8PbnGy0AHB7MhgHcTz6sE2I2yPB
        -----END RSA PRIVATE KEY-----
        """

        #expect {
            try SSHKeyParser.parse(string: rsaPEM)
        } throws: { error in
            guard let parseError = error as? SSHKeyParser.ParseError,
                  case .unsupportedFormat(let message) = parseError
            else {
                return false
            }
            return message.localizedStandardContains("convert")
        }
    }

    @Test("ECDSA P-256 PEM can be parsed")
    func ecdsaPEMParsing() throws {
        // SEC1 EC PEM format (-----BEGIN EC PRIVATE KEY-----), which is
        // what the parser expects. CryptoKit's pemRepresentation produces
        // PKCS#8 format instead, so we use a known-good SEC1 test key.
        // swiftlint:disable:next line_length
        let pem = "-----BEGIN EC PRIVATE KEY-----\nMHcCAQEEIDaM2HbAey+og6cLM9uEFT8BgFm3rPeGinaqFTEQoNDZoAoGCCqGSM49\nAwEHoUQDQgAEEJCuSaXqGWDFeyIH5YKjgX/xHZGCtvLaNSIQKHqiC/QyILISFb+n\nRISGNq3wlNeVGn/aPQWGcO6kgn9VlytAqw==\n-----END EC PRIVATE KEY-----"

        let result = try SSHKeyParser.parse(string: pem)

        guard case .unencrypted(let privateKeyData, let keyType, let publicKeyData) = result else {
            Issue.record("Expected unencrypted result")
            return
        }

        #expect(keyType == .ecdsaP256)
        #expect(!privateKeyData.isEmpty)
        #expect(!publicKeyData.isEmpty)
    }

    @Test("Unrecognized PEM marker throws unsupportedFormat")
    func unrecognizedPEMThrows() {
        let fakePEM = """
        -----BEGIN SOMETHING WEIRD-----
        dGVzdA==
        -----END SOMETHING WEIRD-----
        """

        #expect {
            try SSHKeyParser.parse(string: fakePEM)
        } throws: { error in
            guard let parseError = error as? SSHKeyParser.ParseError,
                  case .unsupportedFormat = parseError
            else {
                return false
            }
            return true
        }
    }
}
