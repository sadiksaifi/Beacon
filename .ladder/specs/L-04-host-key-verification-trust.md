# Phase 4: Host Key Verification & Trust

## 1. Objective
Add host key verification so users are explicitly informed about server identity before connecting, replacing Phase 3's auto-accept behavior with proper trust management.

## 2. Entry Criteria
1. Phase 3 accepted.
2. SSH password auth is functional.
3. Docker harness is available for testing.

## 3. Scope In
- Unknown host blocking prompt with fingerprint display.
- Three trust options: Reject, Trust Once, Trust and Save.
- Host key mismatch warning with Cancel and Replace options.
- Known hosts persistence in Keychain via dedicated `KnownHostsStore`.
- Plain-language security copy (no jargon).

## 4. Scope Out
- SSH key auth (Phase 5).
- Certificate-based host verification.
- DNS-based host key publishing (SSHFP records).

## 5. Product Requirements
- **PR-1:** When connecting to a host with no stored fingerprint, block the connection with a trust decision prompt.
- **PR-2:** Trust prompt displays: host name and port, key type (e.g., "Ed25519", "ECDSA"), fingerprint (SHA-256, formatted as `SHA256:base64...`), and plain-language explanation: "This is the first time you're connecting to this server. Verify this fingerprint matches what you expect."
- **PR-3:** "Don't Connect" cancels the connection attempt and returns to the connection list.
- **PR-4:** "Trust Once" allows this connection only. Fingerprint is NOT saved. Next connection to the same host will prompt again.
- **PR-5:** "Trust and Save" allows the connection and saves the fingerprint. Future connections to this host will not prompt unless the key changes.
- **PR-6:** When connecting to a host with a stored fingerprint that matches the presented key, proceed silently (no prompt).
- **PR-7:** When connecting to a host whose presented key does NOT match the stored fingerprint, block the connection with a security warning.
- **PR-8:** Mismatch warning displays: host name and port, plain-language warning ("This server's identity has changed since you last connected. This could mean the server was reconfigured, or someone may be intercepting your connection."), previously trusted fingerprint, and new fingerprint.
- **PR-9:** "Cancel" on mismatch warning cancels the connection and returns to the connection list.
- **PR-10:** "Replace and Connect" removes the old fingerprint, saves the new one, and proceeds with the connection.
- **PR-11:** "Replace and Connect" must NOT be the default or primary-styled action (to prevent accidental trust override).
- **PR-12:** Saved fingerprints are stored in Keychain with `afterFirstUnlock` access.
- **PR-13:** Each known host entry is keyed by `hostname:port`.
- **PR-14:** Entry stores: hostname, port, key algorithm, fingerprint, first-seen date.
- **PR-15:** "Trust Once" entries are held in memory only — not written to Keychain.

## 6. UX Requirements
- **UX-1:** Security prompts use plain language — no SSH protocol jargon.
- **UX-2:** Unknown host prompt does NOT feel like an error — it's a normal first-connection experience.
- **UX-3:** Mismatch warning DOES feel like a warning — clear visual distinction (e.g., warning icon, yellow/red styling).
- **UX-4:** Fingerprints are displayed in a monospace font for readability.
- **UX-5:** All prompts include enough context for the user to make an informed decision.

## 7. Accessibility Requirements
- **A11Y-1:** Trust prompt is fully navigable with VoiceOver (title, explanation, fingerprint, all buttons).
- **A11Y-2:** Fingerprint text is selectable and VoiceOver-readable.
- **A11Y-3:** Mismatch warning is announced with appropriate urgency by VoiceOver.
- **A11Y-4:** All buttons have descriptive VoiceOver labels.
- **A11Y-5:** All text respects Dynamic Type (except fingerprint, which uses monospace at readable size).

## 8. UAT Checklist
- [ ] UAT-1: Connect to a host for the first time — confirm trust prompt appears with fingerprint.
- [ ] UAT-2: Tap "Don't Connect" — confirm connection is cancelled, returned to list.
- [ ] UAT-3: Connect again and tap "Trust Once" — confirm connection proceeds.
- [ ] UAT-4: Disconnect and reconnect — confirm trust prompt appears again (trust-once did not persist).
- [ ] UAT-5: Connect and tap "Trust and Save" — confirm connection proceeds.
- [ ] UAT-6: Disconnect and reconnect — confirm no prompt appears (fingerprint is saved).
- [ ] UAT-7: Change the Docker harness's SSH host key (regenerate keys).
- [ ] UAT-8: Connect to the same host — confirm mismatch warning appears with both fingerprints.
- [ ] UAT-9: Tap "Cancel" on mismatch — confirm connection is cancelled.
- [ ] UAT-10: Connect again, tap "Replace and Connect" — confirm connection proceeds.
- [ ] UAT-11: Reconnect — confirm no prompt (new key is now saved).

## 9. Test Allocation
| Type | Scope | Method |
|------|-------|--------|
| Unit | TrustDecision model and state transitions | XCTest |
| Unit | KnownHostEntry Keychain storage/retrieval | XCTest |
| Unit | Fingerprint comparison (match, mismatch, missing) | XCTest |
| Unit | Trust Once in-memory store lifecycle | XCTest |
| Critical | Unknown host flow end-to-end against Docker harness | XCTest (integration) |
| Critical | Mismatch flow end-to-end against Docker harness (key regen) | XCTest (integration) |
| Full | End-to-end trust journey UI test (optional) | XCUITest |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. Trust decisions are deterministic — no ambiguous security states.
3. Mismatch warning is clearly distinct from unknown host prompt.
4. Known hosts persist across app relaunch.
5. "Trust Once" does not persist across sessions.
6. No connection proceeds without explicit trust decision for unknown hosts.
7. Known gaps documented before Phase 5.

## 11. Step Sequence

### S1: Remove Phase 3's auto-accept host key behavior
- **Complexity:** small
- **Deliverable:** `SSHConnectionService` no longer auto-accepts host keys; connections to unknown hosts fail or block pending a trust decision
- **Files:** `Beacon/Services/SSHConnectionService.swift`
- **Depends on:** none
- **Details:** Locate the auto-accept host key logic added in Phase 3 (the closure or callback passed to Citadel's `SSHClient` that unconditionally returns success). Remove it so that host key validation is no longer bypassed. After this change, connections to unknown hosts should fail until the callback is wired to the trust decision flow in S3.
- **Acceptance:**
  - [ ] Auto-accept host key closure/callback is removed from `SSHConnectionService`
  - [ ] Connecting to a host without a trust decision mechanism results in a failure (not silent acceptance)
  - [ ] Project builds cleanly

### S2: Define trust decision model and host key types
- **Complexity:** small
- **Deliverable:** `TrustDecision` enum, `HostKeyChallenge` struct, and `KnownHostEntry` struct — the core model types for host key verification
- **Files:** `Beacon/Models/TrustDecision.swift`, `Beacon/Models/KnownHostEntry.swift`
- **Depends on:** none
- **Details:** Create `TrustDecision` as an enum with cases: `.reject`, `.trustOnce`, `.trustAndSave`. Create `HostKeyChallenge` as a struct holding: hostname, port, key type (String), fingerprint (String, SHA-256 base64). Create `KnownHostEntry` as a struct holding: hostname, port, key algorithm, fingerprint, first-seen date. `KnownHostEntry` should be `Codable` for Keychain serialization.
- **Acceptance:**
  - [ ] `TrustDecision` enum has `.reject`, `.trustOnce`, `.trustAndSave` cases
  - [ ] `HostKeyChallenge` holds hostname, port, key type, and fingerprint
  - [ ] `KnownHostEntry` holds hostname, port, algorithm, fingerprint, first-seen date (PR-14)
  - [ ] `KnownHostEntry` conforms to `Codable`
  - [ ] Project builds cleanly

### S3: Implement host key callback in SSH connection service
- **Complexity:** medium
- **Deliverable:** Host key validation callback in `SSHConnectionService` that computes the fingerprint, queries known hosts, and delegates unknown/mismatched keys to a trust decision handler
- **Files:** `Beacon/Services/SSHConnectionService.swift` (updated)
- **Depends on:** S1, S2
- **Details:** Replace the removed auto-accept with a host key validation callback for Citadel's `SSHClient`. The callback receives the server's public key, computes its SHA-256 fingerprint (base64-encoded), builds a `HostKeyChallenge`, and delegates the trust decision to an injectable handler (closure or protocol). The handler will be wired to the UI prompts in later steps. For now, define the handler type and allow injection. If the handler returns `.reject`, the connection fails. If `.trustOnce` or `.trustAndSave`, the connection proceeds.
- **Acceptance:**
  - [ ] Host key callback receives the server's public key from Citadel
  - [ ] Fingerprint is computed as SHA-256 base64 (PR-2)
  - [ ] `HostKeyChallenge` is constructed and passed to the trust decision handler
  - [ ] `.reject` causes connection failure
  - [ ] `.trustOnce` and `.trustAndSave` allow the connection to proceed
  - [ ] Trust decision handler is injectable (for testing and UI wiring)

### S4: Implement fingerprint comparison logic
- **Complexity:** small
- **Deliverable:** Pure function that compares a presented fingerprint against a stored `KnownHostEntry` and returns a comparison result (match, mismatch, or unknown)
- **Files:** `Beacon/Utilities/FingerprintComparer.swift`
- **Depends on:** S2
- **Details:** Create a utility with a static method that takes a `HostKeyChallenge` and an optional `KnownHostEntry` and returns one of three results: `.match` (fingerprints are equal), `.mismatch` (entry exists but fingerprint differs), or `.unknown` (no entry found). This is a pure function with no side effects — it only compares strings. Wire this into the host key callback flow so the callback knows which UI prompt to present.
- **Acceptance:**
  - [ ] Returns `.match` when fingerprints are identical
  - [ ] Returns `.mismatch` when entry exists but fingerprint differs
  - [ ] Returns `.unknown` when no entry is provided (nil)
  - [ ] Function is pure — no side effects or external dependencies
  - [ ] Unit-testable with simple inputs

### S5: Implement known hosts Keychain storage
- **Complexity:** medium
- **Deliverable:** `KnownHostsStore` — a dedicated service for CRUD operations on known host entries in Keychain with `afterFirstUnlock` access
- **Files:** `Beacon/Services/KnownHostsStore.swift`
- **Depends on:** S2
- **Details:** Create `KnownHostsStore` as a new service (separate from Phase 3's `KeychainService` — different concern and access level). Implement methods: `lookup(host:port:) -> KnownHostEntry?` to retrieve a stored entry, `save(_ entry: KnownHostEntry)` to persist a new entry, `replace(host:port:with entry: KnownHostEntry)` to overwrite an existing entry, and `delete(host:port:)` to remove an entry. Key each item by `hostname:port` string. Use `afterFirstUnlock` accessibility (not `userPresence` — no biometric needed for host keys). Serialize `KnownHostEntry` to JSON Data for Keychain storage.
- **Acceptance:**
  - [ ] `save()` persists a `KnownHostEntry` to Keychain (PR-12)
  - [ ] `lookup()` retrieves an entry by hostname:port (PR-13)
  - [ ] `replace()` overwrites an existing entry with a new one
  - [ ] `delete()` removes an entry
  - [ ] Keychain access is `afterFirstUnlock` (PR-12)
  - [ ] Entries survive app relaunch

### S6: Implement Trust Once in-memory behavior
- **Complexity:** small
- **Deliverable:** In-memory trust cache in `KnownHostsStore` for trust-once decisions that do not persist to Keychain
- **Files:** `Beacon/Services/KnownHostsStore.swift` (updated)
- **Depends on:** S5
- **Details:** Add an in-memory dictionary to `KnownHostsStore` keyed by `hostname:port` that stores `KnownHostEntry` values for trust-once decisions. Update the `lookup` method to check in-memory cache first, then Keychain. Add a `trustOnce(_ entry: KnownHostEntry)` method that writes only to the in-memory cache. The in-memory cache is never written to Keychain and is cleared when the app process terminates (no explicit cleanup needed — memory lifecycle handles it).
- **Acceptance:**
  - [ ] `trustOnce()` stores entry in memory only — not in Keychain (PR-15)
  - [ ] `lookup()` finds trust-once entries during the same session
  - [ ] Trust-once entries do not survive app relaunch
  - [ ] Trust-once and saved entries coexist without conflict

### S7: Build unknown host trust prompt UI
- **Complexity:** medium
- **Deliverable:** `UnknownHostPromptView` — a blocking prompt shown when connecting to an unrecognized host, presenting fingerprint and three trust actions
- **Files:** `Beacon/Views/SSH/UnknownHostPromptView.swift`
- **Depends on:** S3
- **Details:** Create a SwiftUI view presented as a sheet or full-screen cover from `SSHSessionView` when the host key callback signals an unknown host. Display the host name and port, key type, fingerprint in monospace font, and the plain-language explanation text. Provide three buttons: "Don't Connect" (returns `.reject`), "Trust Once" (returns `.trustOnce`), "Trust and Save" (returns `.trustAndSave`). The view must feel informational, not alarming — it's a normal first-connection experience. Wire the selected `TrustDecision` back to the host key callback's continuation.
- **Acceptance:**
  - [ ] Prompt appears when connecting to a host with no stored fingerprint (PR-1)
  - [ ] Displays host name, port, key type, and fingerprint (PR-2)
  - [ ] Fingerprint is rendered in monospace font (UX-4)
  - [ ] Plain-language explanation is shown (PR-2, UX-1)
  - [ ] "Don't Connect" cancels and returns to connection list (PR-3)
  - [ ] "Trust Once" allows the connection without saving (PR-4)
  - [ ] "Trust and Save" allows the connection and saves the fingerprint (PR-5)
  - [ ] Prompt does not feel like an error (UX-2)

### S8: Build mismatch warning UI
- **Complexity:** medium
- **Deliverable:** `MismatchWarningView` — a security warning shown when a host's key does not match the stored fingerprint, with Cancel and Replace actions
- **Files:** `Beacon/Views/SSH/MismatchWarningView.swift`
- **Depends on:** S3
- **Details:** Create a SwiftUI view presented as a sheet or full-screen cover from `SSHSessionView` when the host key callback signals a fingerprint mismatch. Display the host name and port, the plain-language warning text, the previously trusted fingerprint, and the new fingerprint — both in monospace font. Provide two buttons: "Cancel" (returns `.reject`) and "Replace and Connect" (returns `.trustAndSave`). "Replace and Connect" must NOT be the default or primary-styled button — use a secondary or destructive style to prevent accidental trust override. The view must feel like a warning with clear visual distinction (warning icon, yellow/red styling).
- **Acceptance:**
  - [ ] Warning appears when stored fingerprint does not match presented key (PR-7)
  - [ ] Displays host name, port, warning text, old fingerprint, and new fingerprint (PR-8)
  - [ ] Both fingerprints are rendered in monospace font (UX-4)
  - [ ] "Cancel" cancels and returns to connection list (PR-9)
  - [ ] "Replace and Connect" removes old fingerprint and saves new one (PR-10)
  - [ ] "Replace and Connect" is NOT the default or primary-styled action (PR-11)
  - [ ] Warning has clear visual distinction from unknown host prompt (UX-3)

### S9: Add VoiceOver labels to all prompt elements
- **Complexity:** small
- **Deliverable:** Full accessibility coverage for trust prompt and mismatch warning UI elements
- **Files:** `Beacon/Views/SSH/UnknownHostPromptView.swift` (updated), `Beacon/Views/SSH/MismatchWarningView.swift` (updated)
- **Depends on:** S7, S8
- **Details:** Add `.accessibilityLabel` to all buttons with clear, descriptive labels. Ensure fingerprint text is selectable and VoiceOver-readable. Use `AccessibilityNotification.announcement` with appropriate urgency for the mismatch warning. Ensure all text except fingerprint uses Dynamic Type-compatible font styles. Verify the full VoiceOver navigation order is logical: title → explanation → fingerprint → actions.
- **Acceptance:**
  - [ ] Trust prompt is fully navigable with VoiceOver (A11Y-1)
  - [ ] Fingerprint text is selectable and VoiceOver-readable (A11Y-2)
  - [ ] Mismatch warning is announced with appropriate urgency (A11Y-3)
  - [ ] All buttons have descriptive VoiceOver labels (A11Y-4)
  - [ ] All text respects Dynamic Type except monospace fingerprint (A11Y-5)

### S10: Write integration tests against Docker harness
- **Complexity:** medium
- **Deliverable:** XCTest integration tests for unknown host flow, trusted host flow, and mismatch flow, runnable against the Docker test harness
- **Files:** `BeaconTests/HostKeyVerificationTests.swift`
- **Depends on:** S9
- **Details:** Write XCTest tests that instantiate `SSHConnectionService` with a mock trust decision handler and connect to the Docker harness. Test 1: Unknown host — verify callback fires with a `HostKeyChallenge` and `.unknown` comparison result. Test 2: Trusted host — save a fingerprint via `KnownHostsStore`, reconnect, verify no callback (silent proceed). Test 3: Mismatch — regenerate the Docker harness's SSH keys, reconnect, verify callback fires with `.mismatch` result. Guard each test with a precondition check for harness availability and skip gracefully if not reachable.
- **Acceptance:**
  - [ ] Test file builds as part of the BeaconTests target
  - [ ] Unknown host flow test passes against Docker harness
  - [ ] Trusted host (silent proceed) test passes
  - [ ] Mismatch flow test passes after Docker harness key regeneration
  - [ ] Tests skip gracefully when Docker harness is not reachable

### S11: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** Verified UAT pass on simulator against the Docker test harness
- **Files:** none (verification step)
- **Depends on:** S10
- **Details:** Walk through all 11 UAT checklist items on the iOS simulator with the Docker harness running. Verify all three flows: unknown host (prompt → Don't Connect / Trust Once / Trust and Save), trusted host (silent proceed), and mismatch (warning → Cancel / Replace and Connect). Confirm trust-once does not persist across reconnect, trust-and-save does persist, and replaced keys are saved correctly. Document any deviations or known gaps before starting Phase 5.
- **Acceptance:**
  - [ ] All UAT checklist items (UAT-1 through UAT-11) pass
  - [ ] No ambiguous security states observed
  - [ ] Known gaps documented before Phase 5

## 12. References
- [security-architecture.md](../refs/security-architecture.md) (Section 5: Known Hosts Storage)
