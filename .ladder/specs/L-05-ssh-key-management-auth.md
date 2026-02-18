# Phase 5: SSH Key Management & Key Auth

## 1. Objective
Enable SSH public key authentication by providing key generation, import, secure storage, and connection integration.

## 2. Entry Criteria
1. Phase 4 accepted.
2. Password auth and host key verification are functional.
3. Docker harness supports public key auth.

## 3. Scope In
- SSH key generation (Ed25519 default, ECDSA P-256).
- SSH key import via clipboard paste and Files app document picker.
- Key storage in Keychain with biometric protection (FaceID/TouchID).
- Dedicated Keys tab in the main tab bar for key management.
- Key selection in connection form's auth method picker.
- Public key display and copy (for user to add to `authorized_keys`).
- Connect using public key authentication via Citadel.

## 4. Scope Out
- RSA key generation (import only, due to Citadel limitations).
- SSH agent forwarding.
- Passphrase-protected key usage at runtime (keys are decrypted on import and re-stored in Keychain).
- Certificate-based authentication.

## 5. Product Requirements
- **PR-1:** Key management is accessible from a dedicated "Keys" tab in the main tab bar.
- **PR-2:** User can generate a new SSH key pair from a "Generate Key" action.
- **PR-3:** Default algorithm: Ed25519. Option to select ECDSA P-256.
- **PR-4:** User provides a label/name for the key (e.g., "My iPhone Key").
- **PR-5:** Private key is generated on-device and stored immediately in Keychain.
- **PR-6:** Public key is derived and displayed for the user to copy.
- **PR-7:** Generation UI shows clear success with public key ready to copy.
- **PR-8:** User can import an existing private key via clipboard paste ("Paste from Clipboard" button) or Files app document picker ("Import from Files" button).
- **PR-9:** Import validates the key: must be a private key (not public only), supported formats PEM and OpenSSH, supported types Ed25519, ECDSA P-256, RSA.
- **PR-10:** If passphrase-protected: prompt for passphrase, decrypt, store unencrypted in Keychain.
- **PR-11:** Invalid or unsupported keys show a clear error message explaining what's wrong.
- **PR-12:** User provides a label for the imported key.
- **PR-13:** Imported private key is stored in Keychain with biometric access control.
- **PR-14:** Private keys are stored in Keychain with `biometryCurrentSet` access control.
- **PR-15:** Accessing a stored key requires FaceID/TouchID verification.
- **PR-16:** If biometric enrollment changes (new fingerprint added), stored keys become inaccessible (security feature — user must re-import).
- **PR-17:** Keys are NOT synced via iCloud Keychain.
- **PR-18:** Each key is identified by a unique key ID and user-provided label.
- **PR-19:** When auth method is "SSH Key," a key picker appears in the connection form.
- **PR-20:** Key picker lists all stored keys by label.
- **PR-21:** If no keys exist, picker shows "No keys — generate or import one" with action link to the Keys tab.
- **PR-22:** Selected key ID is stored in the connection model.
- **PR-23:** User can view the public key for any stored key.
- **PR-24:** Public key is displayed in OpenSSH format (ready to paste into `authorized_keys`).
- **PR-25:** "Copy to Clipboard" button copies the public key text.
- **PR-26:** When connecting with auth method "SSH Key," retrieve the selected private key from Keychain (triggers biometric prompt) and use it for SSH public key authentication via Citadel.
- **PR-27:** On auth success: proceed to Connected state.
- **PR-28:** On auth failure: show "Key authentication failed — the server may not have your public key in authorized_keys."
- **PR-29:** If biometric verification fails: show "Authentication cancelled" (do not connect).

## 6. UX Requirements
- **UX-1:** Key generation feels like a simple, guided flow — not a technical operation.
- **UX-2:** Public key copy is prominent and easy to find (users need this to set up servers).
- **UX-3:** Import errors clearly explain what went wrong and what key formats are accepted.
- **UX-4:** Biometric prompt explains why it's needed: "Beacon needs to access your SSH key."

## 7. Accessibility Requirements
- **A11Y-1:** Key list items have VoiceOver labels with key name and type.
- **A11Y-2:** Generate and Import buttons have descriptive VoiceOver labels.
- **A11Y-3:** Public key text area is VoiceOver-readable.
- **A11Y-4:** Copy button is labeled "Copy public key to clipboard" for VoiceOver.
- **A11Y-5:** All text respects Dynamic Type.

## 8. UAT Checklist
- [ ] UAT-1: Generate an Ed25519 key — confirm key appears in key list.
- [ ] UAT-2: View the public key — confirm it displays in OpenSSH format.
- [ ] UAT-3: Copy the public key — confirm clipboard contains the key.
- [ ] UAT-4: Add the public key to Docker harness's `authorized_keys`.
- [ ] UAT-5: Create/edit a connection with auth method "SSH Key" and select the generated key.
- [ ] UAT-6: Connect — confirm biometric prompt appears, then connection succeeds.
- [ ] UAT-7: Import a key via clipboard paste — confirm it appears in key list.
- [ ] UAT-8: Import a key via Files app — confirm it appears in key list.
- [ ] UAT-9: Attempt to import an invalid file — confirm clear error message.
- [ ] UAT-10: Generate an ECDSA P-256 key — confirm it works for connection.
- [ ] UAT-11: Connect with key auth to a server that does NOT have the public key — confirm clear error message.

## 9. Test Allocation
| Type | Scope | Method |
|------|-------|--------|
| Unit | SSH key generation (Ed25519, ECDSA P-256) | XCTest |
| Unit | Key parsing and validation (PEM, OpenSSH formats) | XCTest |
| Unit | Keychain storage/retrieval (mock) | XCTest |
| Unit | Key type detection | XCTest |
| Unit | Connection form key selection logic | XCTest |
| Critical | Key auth flow against Docker harness (Ed25519) | XCTest (integration) |
| Critical | Key import flow (clipboard and Files) | XCTest (integration) |
| Full | End-to-end UI flow from key generation to connected session | XCUITest (optional) |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. Ed25519 and ECDSA keys can be generated and used for auth.
3. Key import from clipboard and Files app works.
4. Keys are stored with biometric protection.
5. Key auth connection flow is functional end-to-end.
6. Known gaps documented before Phase 6.

## 11. Step Sequence

### S1: Define SSH key model types
- **Complexity:** small
- **Deliverable:** `SSHKeyEntry` model and `SSHKeyType` enum — the core types for representing stored SSH keys
- **Files:** `Beacon/Models/SSHKeyEntry.swift`
- **Depends on:** none
- **Details:** Define `SSHKeyType` as an enum with cases `.ed25519`, `.ecdsaP256`, `.rsa`. Define `SSHKeyEntry` as a struct holding: `id` (UUID), `label` (String), `keyType` (SSHKeyType), `publicKey` (Data), `keychainID` (String, for Keychain item lookup), `createdAt` (Date). `SSHKeyEntry` should be `Codable` for persistence of the metadata (private key data itself lives in Keychain, not in this struct).
- **Acceptance:**
  - [ ] `SSHKeyType` has `.ed25519`, `.ecdsaP256`, `.rsa` cases
  - [ ] `SSHKeyEntry` holds id, label, keyType, publicKey, keychainID, createdAt (PR-18)
  - [ ] `SSHKeyEntry` conforms to `Codable`
  - [ ] Project builds cleanly

### S2: Implement SSH key generation logic
- **Complexity:** medium
- **Deliverable:** `SSHKeyGenerator` — a service that generates Ed25519 and ECDSA P-256 key pairs on-device and returns the private key data and derived public key in OpenSSH format
- **Files:** `Beacon/Services/SSHKeyGenerator.swift`
- **Depends on:** S1
- **Details:** Create `SSHKeyGenerator` with a method `generate(type: SSHKeyType, label: String) -> (privateKey: Data, publicKey: String)` (or equivalent async signature). For Ed25519, use `Curve25519.Signing` from CryptoKit (or Citadel's key types if more compatible). For ECDSA P-256, use `P256.Signing` from CryptoKit. Derive the public key in OpenSSH wire format (e.g., `ssh-ed25519 AAAA...`). RSA generation is out of scope (import only). Ensure all key generation happens on-device with no network calls (PR-5).
- **Acceptance:**
  - [ ] Ed25519 key pair is generated successfully (PR-2, PR-3)
  - [ ] ECDSA P-256 key pair is generated successfully (PR-3)
  - [ ] Public key is derived in OpenSSH format (PR-6, PR-24)
  - [ ] Generation happens entirely on-device (PR-5)
  - [ ] Project builds cleanly

### S3: Implement Keychain storage for SSH private keys
- **Complexity:** medium
- **Deliverable:** `SSHKeyStore` — a service for storing, retrieving, listing, and deleting SSH private keys in Keychain with biometric access control
- **Files:** `Beacon/Services/SSHKeyStore.swift`
- **Depends on:** S1
- **Details:** Create `SSHKeyStore` with methods: `save(privateKey: Data, entry: SSHKeyEntry)` to store a private key in Keychain keyed by the entry's `keychainID`, `retrieve(keychainID: String) async -> Data?` to fetch the private key (triggers biometric prompt), `list() -> [SSHKeyEntry]` to return all stored key metadata, and `delete(keychainID: String)` to remove a key. Apply `SecAccessControlCreateWithFlags(.biometryCurrentSet)` on write so retrieval requires FaceID/TouchID (PR-14). Disable iCloud Keychain sync by setting `kSecAttrSynchronizable` to false (PR-17). Key metadata (SSHKeyEntry list) is stored separately (e.g., as a JSON blob in Keychain or UserDefaults) for listing without biometric.
- **Acceptance:**
  - [ ] Private key can be stored with biometric access control (PR-14)
  - [ ] Stored key can be retrieved — triggers biometric prompt (PR-15)
  - [ ] All stored keys can be listed by metadata without biometric (PR-20)
  - [ ] Key can be deleted
  - [ ] Keys are NOT synced via iCloud Keychain (PR-17)
  - [ ] Biometric enrollment change invalidates stored keys (PR-16)

### S4: Build key list view and add Keys tab
- **Complexity:** medium
- **Deliverable:** `KeyListView` showing all stored SSH keys, and a new "Keys" tab in the main tab bar
- **Files:** `Beacon/Views/Keys/KeyListView.swift`, `Beacon/Views/MainTabView.swift` (updated)
- **Depends on:** S3
- **Details:** Add a "Keys" tab to `MainTabView` using an appropriate SF Symbol (e.g., `key`). Create `KeyListView` as a NavigationStack displaying stored keys from `SSHKeyStore.list()`. Each row shows the key label and type. Include toolbar actions or buttons for "Generate Key" and "Import Key" that navigate to the respective flows (built in S5 and S8). If no keys exist, show an empty state encouraging the user to generate or import a key.
- **Acceptance:**
  - [ ] "Keys" tab appears in the main tab bar (PR-1)
  - [ ] Key list displays stored keys by label (PR-20)
  - [ ] "Generate Key" and "Import Key" actions are accessible
  - [ ] Empty state is shown when no keys exist
  - [ ] Tab uses NavigationStack with large title

### S5: Build key generation UI flow
- **Complexity:** medium
- **Deliverable:** `KeyGenerationView` — a guided flow for generating a new SSH key with label input, algorithm selection, and public key display on success
- **Files:** `Beacon/Views/Keys/KeyGenerationView.swift`
- **Depends on:** S2, S3, S4
- **Details:** Create `KeyGenerationView` presented from `KeyListView`. The flow: user enters a label, selects algorithm (Ed25519 default, ECDSA P-256 option), taps "Generate." On generate: call `SSHKeyGenerator.generate()`, store the private key via `SSHKeyStore.save()`, then transition to a success state showing the public key in OpenSSH format with a prominent "Copy" button. The flow should feel simple and guided — not a technical operation (UX-1). On dismiss, return to KeyListView where the new key appears.
- **Acceptance:**
  - [ ] User can enter a label for the key (PR-4)
  - [ ] Ed25519 is the default algorithm with ECDSA P-256 as an option (PR-3)
  - [ ] Tapping "Generate" creates the key and stores it in Keychain (PR-5)
  - [ ] Success state shows the public key ready to copy (PR-6, PR-7)
  - [ ] Flow feels simple and guided (UX-1)
  - [ ] New key appears in key list after dismissal

### S6: Build public key display and copy-to-clipboard
- **Complexity:** small
- **Deliverable:** `PublicKeyDisplayView` — a view showing the public key in OpenSSH format with a copy-to-clipboard button
- **Files:** `Beacon/Views/Keys/PublicKeyDisplayView.swift`
- **Depends on:** S5
- **Details:** Create `PublicKeyDisplayView` accessible from key list rows (tapping a key shows its public key). Display the public key string in OpenSSH format in a selectable, monospace text area. Provide a prominent "Copy to Clipboard" button that copies the text via `UIPasteboard.general`. Show brief confirmation feedback after copying (e.g., button text changes to "Copied"). This is also reused by the generation success state in S5.
- **Acceptance:**
  - [ ] Public key is viewable for any stored key (PR-23)
  - [ ] Displayed in OpenSSH format (PR-24)
  - [ ] "Copy to Clipboard" button copies the key text (PR-25)
  - [ ] Copy button is prominent and easy to find (UX-2)
  - [ ] Copy confirmation feedback is shown

### S7: Implement SSH key parser for import
- **Complexity:** medium
- **Deliverable:** `SSHKeyParser` — a service that parses PEM and OpenSSH private key formats, detects key type, and validates the key
- **Files:** `Beacon/Services/SSHKeyParser.swift`
- **Depends on:** S1
- **Details:** Create `SSHKeyParser` with a method `parse(data: Data) -> ParsedKey` (or throws on failure). Support PEM-encoded private keys (BEGIN/END markers) and OpenSSH format (`-----BEGIN OPENSSH PRIVATE KEY-----`). Detect key type (Ed25519, ECDSA P-256, RSA) from the parsed data. Validate that the input is a private key (not public only). Detect if the key is passphrase-protected (encrypted PEM or OpenSSH `bcrypt` KDF). Return a result containing: raw private key data, key type, whether it's encrypted, and the derived public key.
- **Acceptance:**
  - [ ] Parses PEM-format private keys (PR-9)
  - [ ] Parses OpenSSH-format private keys (PR-9)
  - [ ] Detects key type: Ed25519, ECDSA P-256, RSA (PR-9)
  - [ ] Rejects public-only keys with clear error (PR-9)
  - [ ] Detects passphrase-protected keys (PR-10)
  - [ ] Invalid or unsupported input produces a descriptive error (PR-11)

### S8: Build key import from clipboard
- **Complexity:** medium
- **Deliverable:** `KeyImportView` — import flow with "Paste from Clipboard" button that reads, parses, validates, and stores the key
- **Files:** `Beacon/Views/Keys/KeyImportView.swift`
- **Depends on:** S3, S4, S7
- **Details:** Create `KeyImportView` presented from `KeyListView`. Include a "Paste from Clipboard" button that reads `UIPasteboard.general.string`, passes it to `SSHKeyParser.parse()`, and on success prompts the user for a label. After labeling, store the private key via `SSHKeyStore.save()` and return to the key list. On parse failure, display a clear error message explaining what's wrong and what formats are accepted (UX-3). If the key is passphrase-protected, defer to S10's passphrase prompt before storing.
- **Acceptance:**
  - [ ] "Paste from Clipboard" reads clipboard content (PR-8)
  - [ ] Parsed key is validated via SSHKeyParser (PR-9)
  - [ ] User provides a label for the imported key (PR-12)
  - [ ] Valid key is stored in Keychain with biometric access control (PR-13)
  - [ ] Invalid key shows a clear error with accepted formats (PR-11, UX-3)

### S9: Build key import from Files app
- **Complexity:** medium
- **Deliverable:** Document picker integration in `KeyImportView` for importing a private key file from the Files app
- **Files:** `Beacon/Views/Keys/KeyImportView.swift` (updated)
- **Depends on:** S8
- **Details:** Add an "Import from Files" button to `KeyImportView` that presents the standard iOS document picker (`UIDocumentPickerViewController` bridged via `UIViewControllerRepresentable`). On file selection, read the file contents, pass to `SSHKeyParser.parse()`, and follow the same validation → label → store flow as clipboard import. Handle file access security scoping (`startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`).
- **Acceptance:**
  - [ ] "Import from Files" opens the iOS document picker (PR-8)
  - [ ] Selected file is read and parsed via SSHKeyParser (PR-9)
  - [ ] Valid key follows the same label → store flow as clipboard import
  - [ ] File access security scoping is handled correctly
  - [ ] Invalid file shows a clear error message (PR-11, UX-3)

### S10: Add passphrase prompt for encrypted keys
- **Complexity:** small
- **Deliverable:** Passphrase entry prompt during import that decrypts the key before Keychain storage
- **Files:** `Beacon/Views/Keys/KeyImportView.swift` (updated), `Beacon/Services/SSHKeyParser.swift` (updated)
- **Depends on:** S8
- **Details:** When `SSHKeyParser` detects a passphrase-protected key, present a secure text field prompting for the passphrase. Pass the passphrase to a `decrypt(data:passphrase:)` method on `SSHKeyParser` that decrypts the key. On success, store the decrypted private key in Keychain (the key is stored unencrypted in Keychain, protected by biometric instead). On wrong passphrase, show an error and allow retry.
- **Acceptance:**
  - [ ] Passphrase prompt appears for encrypted keys (PR-10)
  - [ ] Correct passphrase decrypts the key successfully
  - [ ] Decrypted key is stored unencrypted in Keychain (PR-10)
  - [ ] Wrong passphrase shows an error with retry option

### S11: Add key picker to connection form
- **Complexity:** small
- **Deliverable:** Key picker in the connection form when auth method is "SSH Key," plus `selectedKeyID` field on the Connection model
- **Files:** `Beacon/Views/Connections/ConnectionFormView.swift` (updated), `Beacon/Models/Connection.swift` (updated)
- **Depends on:** S4
- **Details:** Add an optional `selectedKeyID: UUID?` property to the `Connection` model. In `ConnectionFormView`, when `authMethod` is `.key`, show a Picker listing all stored keys by label (fetched from `SSHKeyStore.list()`). Bind the selected key's ID to `connection.selectedKeyID`. If no keys exist, show "No keys — generate or import one" with a navigation link to the Keys tab. Hide the picker when auth method is `.password`.
- **Acceptance:**
  - [ ] Key picker appears when auth method is "SSH Key" (PR-19)
  - [ ] Picker lists all stored keys by label (PR-20)
  - [ ] "No keys" state shows with action link when no keys exist (PR-21)
  - [ ] Selected key ID is stored in the connection model (PR-22)
  - [ ] Picker is hidden when auth method is "Password"

### S12: Integrate key auth flow in SSH connection service
- **Complexity:** medium
- **Deliverable:** Public key authentication path in `SSHConnectionService` that retrieves the selected private key from Keychain and authenticates via Citadel
- **Files:** `Beacon/Services/SSHConnectionService.swift` (updated)
- **Depends on:** S3, S11
- **Details:** Extend `SSHConnectionService.connect()` to handle `.key` auth method. When auth method is key: look up `selectedKeyID` on the Connection, retrieve the private key from `SSHKeyStore.retrieve()` (triggers biometric prompt), and pass the key to Citadel's public key authentication API. If biometric is cancelled, transition to `.failed` with "Authentication cancelled." If Citadel key auth succeeds, proceed to `.connected`. If it fails, transition to `.failed` with the appropriate error message (S13).
- **Acceptance:**
  - [ ] Key is retrieved from Keychain — triggers biometric prompt (PR-26)
  - [ ] Private key is passed to Citadel for public key authentication (PR-26)
  - [ ] On auth success: state transitions to `.connected` (PR-27)
  - [ ] On biometric cancellation: state transitions to `.failed` with "Authentication cancelled" (PR-29)
  - [ ] On auth failure: state transitions to `.failed` with appropriate message

### S13: Map key auth errors to human-readable messages
- **Complexity:** small
- **Deliverable:** Key auth failure and biometric cancellation error messages added to `SSHErrorMapper`
- **Files:** `Beacon/Utilities/SSHErrorMapper.swift` (updated)
- **Depends on:** S12
- **Details:** Extend the existing `SSHErrorMapper` (from Phase 3) to handle key auth-specific errors. Map Citadel key auth rejection to "Key authentication failed — the server may not have your public key in authorized_keys." Map Keychain biometric cancellation (`errSecUserCanceled`) to "Authentication cancelled." Ensure these messages follow the same plain-language style as Phase 3 errors.
- **Acceptance:**
  - [ ] Key auth rejection maps to the specified message (PR-28)
  - [ ] Biometric cancellation maps to "Authentication cancelled" (PR-29)
  - [ ] Error messages follow plain-language style

### S14: Add VoiceOver labels to all key management elements
- **Complexity:** small
- **Deliverable:** Full accessibility coverage for all key management views
- **Files:** `Beacon/Views/Keys/KeyListView.swift` (updated), `Beacon/Views/Keys/KeyGenerationView.swift` (updated), `Beacon/Views/Keys/PublicKeyDisplayView.swift` (updated), `Beacon/Views/Keys/KeyImportView.swift` (updated), `Beacon/Views/Connections/ConnectionFormView.swift` (updated)
- **Depends on:** S6, S9, S10, S11, S13
- **Details:** Add `.accessibilityLabel` to key list rows with key name and type. Add descriptive VoiceOver labels to Generate Key and Import Key buttons. Ensure the public key text area is VoiceOver-readable. Label the copy button "Copy public key to clipboard." Verify all text uses Dynamic Type-compatible font styles. Ensure logical VoiceOver navigation order in all key management screens.
- **Acceptance:**
  - [ ] Key list items have VoiceOver labels with key name and type (A11Y-1)
  - [ ] Generate and Import buttons have descriptive VoiceOver labels (A11Y-2)
  - [ ] Public key text area is VoiceOver-readable (A11Y-3)
  - [ ] Copy button is labeled "Copy public key to clipboard" (A11Y-4)
  - [ ] All text respects Dynamic Type (A11Y-5)

### S15: Write integration tests against Docker harness
- **Complexity:** medium
- **Deliverable:** XCTest integration tests for key generation and key auth flow, runnable against the Docker test harness with `authorized_keys` configured
- **Files:** `BeaconTests/SSHKeyAuthTests.swift`
- **Depends on:** S14
- **Details:** Write XCTest tests that exercise the key auth flow end-to-end. Test 1: Generate an Ed25519 key, extract the public key, add it to the Docker harness's `authorized_keys`, and connect using key auth — verify the connection succeeds. Test 2: Attempt key auth with a key NOT in `authorized_keys` — verify the connection fails with the expected error message. Test 3: Import a key via the parser and verify it's stored and retrievable. Guard each test with a precondition check for harness availability and skip gracefully if not reachable.
- **Acceptance:**
  - [ ] Test file builds as part of the BeaconTests target
  - [ ] Ed25519 key auth test passes against Docker harness
  - [ ] Key auth failure test produces expected error message
  - [ ] Key import/parse test passes
  - [ ] Tests skip gracefully when Docker harness is not reachable

### S16: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** Verified UAT pass on simulator against the Docker test harness
- **Files:** none (verification step)
- **Depends on:** S15
- **Details:** Walk through all 11 UAT checklist items on the iOS simulator with the Docker harness running. Verify key generation (Ed25519 and ECDSA), public key display and copy, key import (clipboard and Files app), key picker in connection form, and key auth connection flow. Test error cases: invalid import, auth failure with missing public key. Document any deviations or known gaps before starting Phase 6.
- **Acceptance:**
  - [ ] All UAT checklist items (UAT-1 through UAT-11) pass
  - [ ] No crashes or stuck states observed
  - [ ] Known gaps documented before Phase 6

## 12. References
- [ssh-library-decision.md](../refs/ssh-library-decision.md) (key type support)
- [security-architecture.md](../refs/security-architecture.md) (Sections 3-4: key management and Secure Enclave)
