# Reference: Security Architecture

## 1. Context
Beacon stores and uses sensitive credentials: SSH passwords, private keys, and known host fingerprints. This document defines how these are stored, protected, and accessed on iOS.

## 2. iOS Keychain Integration

### 2.1 What is Keychain
iOS Keychain Services provides hardware-backed encrypted storage for sensitive data. Data is encrypted at rest using the device's Secure Enclave and is protected by the device passcode. Keychain items survive app updates and can be configured with access control policies.

### 2.2 What Beacon Stores in Keychain

| Item | Keychain Class | Access Control | Notes |
|---|---|---|---|
| SSH passwords | `kSecClassGenericPassword` | `userPresence` (biometric or passcode) | Per-connection, keyed by connection ID |
| SSH private keys | `kSecClassGenericPassword` | `biometryCurrentSet` (FaceID/TouchID) | Stored as PEM/OpenSSH format data blob |
| Known host fingerprints | `kSecClassGenericPassword` | `afterFirstUnlock` | Not biometric-gated (low sensitivity, needed for auto-reconnect) |

### 2.3 Access Control Policies

**Passwords and Private Keys:**
- Require biometric authentication (FaceID or TouchID) OR device passcode
- Use `SecAccessControlCreateFlags.biometryCurrentSet` for keys — this invalidates stored items if biometric enrollment changes (e.g., new fingerprint added), which is a security best practice
- For passwords, use `.userPresence` which allows either biometric or passcode fallback
- Items are only accessible when the device is unlocked

**Known Hosts:**
- Use `kSecAttrAccessibleAfterFirstUnlock` — accessible after first device unlock, even if device is subsequently locked
- This allows reconnect flows to verify host keys without requiring the user to re-authenticate to Keychain
- Lower sensitivity: host fingerprints are not secrets (they're the server's public identity)

### 2.4 Keychain Item Organization
- **Service name:** `com.beacon.ssh` (consistent prefix for all Beacon Keychain items)
- **Account key for passwords:** `password:{connectionID}`
- **Account key for private keys:** `key:{keyID}`
- **Account key for known hosts:** `knownhost:{hostname}:{port}`
- All items include `kSecAttrSynchronizable: false` — credentials do NOT sync via iCloud Keychain

## 3. SSH Key Management

### 3.1 Key Types Supported
| Algorithm | Support Level | Notes |
|---|---|---|
| Ed25519 | Default for generation | Modern, fast, small keys, recommended |
| ECDSA P-256 | Supported for generation and import | Wide server compatibility |
| RSA (2048/4096) | Import only | Legacy support; generation not offered due to Citadel limitations |

### 3.2 Key Generation
- Keys are generated on-device using Apple's Security framework or CryptoKit
- Ed25519: generated via CryptoKit `Curve25519.Signing.PrivateKey`
- ECDSA P-256: generated via CryptoKit `P256.Signing.PrivateKey`
- Private key is immediately stored in Keychain after generation
- Public key is derived and displayed for the user to copy (for adding to `~/.ssh/authorized_keys` on servers)

### 3.3 Key Import
Users can import existing SSH keys via:
1. **Clipboard paste**: Paste PEM or OpenSSH format private key from clipboard
2. **Files app**: Use iOS document picker to select a key file

Import validation:
- Parse key format (PEM, OpenSSH)
- Verify key is a private key (not just public)
- Detect key type (Ed25519, ECDSA, RSA)
- If passphrase-protected: prompt for passphrase, decrypt, re-store in Keychain without passphrase (Keychain provides the encryption at rest)
- Reject unsupported key types with clear message

### 3.4 Key Storage Format
Private keys are stored in Keychain as serialized data blobs in OpenSSH format. The Keychain provides encryption at rest; no additional application-level encryption is applied (this would be redundant and add complexity).

## 4. Secure Enclave Considerations

### 4.1 What the Secure Enclave Can Do
The Secure Enclave can generate and store ECDSA P-256 keys that never leave the hardware. Private key operations (signing) happen inside the enclave.

### 4.2 Why Beacon Does Not Use Secure Enclave for SSH Keys
- Secure Enclave only supports ECDSA P-256 — no Ed25519, no RSA
- SSH keys need to be in a format the SSH protocol understands; Secure Enclave keys cannot be exported
- The Secure Enclave's signing API does not directly produce SSH-compatible signatures
- Keychain with biometric access control provides sufficient protection for SSH keys

### 4.3 Biometric Protection Equivalence
Using `biometryCurrentSet` access control on Keychain items provides a similar security guarantee to Secure Enclave for most threat models:
- Key material is encrypted at rest by the Secure Enclave's key hierarchy
- Access requires biometric verification
- If biometric enrollment changes, the item becomes inaccessible

## 5. Known Hosts Storage

### 5.1 Data Model
Each known host entry stores:
- Hostname
- Port
- Host key algorithm (e.g., `ssh-ed25519`, `ecdsa-sha2-nistp256`)
- Host key fingerprint (SHA-256 hash, base64 encoded)
- Trust level: `once` (ephemeral, not persisted) or `saved` (persisted in Keychain)
- First seen date

### 5.2 Verification Flow
1. SSH connection begins handshake
2. Server presents host key
3. Beacon computes fingerprint of presented key
4. Look up stored entry for `hostname:port`
5. If no entry: **unknown host** → show trust prompt (Phase 4)
6. If entry exists and matches: **trusted** → proceed silently
7. If entry exists and does NOT match: **mismatch** → show security warning (Phase 4)

### 5.3 Trust-Once Behavior
"Trust once" entries are held in memory only for the current app session. They are not written to Keychain. On app restart, the host will prompt again.

## 6. Data at Rest Summary

| Data | Storage Location | Encryption | Access Control |
|---|---|---|---|
| Connection metadata (host, port, username, label) | SwiftData / local database | iOS file protection (complete) | App sandbox |
| SSH passwords | Keychain | Hardware-backed (Secure Enclave key hierarchy) | Biometric or passcode |
| SSH private keys | Keychain | Hardware-backed (Secure Enclave key hierarchy) | Biometric (current set) |
| Known host fingerprints | Keychain | Hardware-backed (Secure Enclave key hierarchy) | After first unlock |
| Terminal scrollback snapshot | App sandbox (temporary) | iOS file protection (complete until first auth) | App sandbox |

## 7. What Beacon Does NOT Do
- Does NOT implement custom encryption on top of Keychain (redundant)
- Does NOT sync credentials via iCloud (explicit choice for security)
- Does NOT store passwords or keys in UserDefaults, plist files, or Core Data
- Does NOT log sensitive credential data
- Does NOT transmit credentials to any server other than the SSH target

## 8. Referenced By
- [Phase 3: SSH Connect & Password Auth](../specs/L-03-ssh-connect-password-auth.md) (password Keychain storage)
- [Phase 4: Host Key Verification & Trust](../specs/L-04-host-key-verification-trust.md) (known hosts)
- [Phase 5: SSH Key Management & Key Auth](../specs/L-05-ssh-key-management-auth.md) (key generation, import, storage)
- [Phase 14: Settings Screen](../specs/L-14-settings-screen.md) (key listing, deletion)
