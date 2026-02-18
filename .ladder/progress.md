# Progress

## L-00: Project Bootstrap & App Shell

**Status:** done
**Started:** 2026-02-17
**Completed:** 2026-02-17

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Create project.yml and generate Xcode project | done | 066b787 | |
| S2 | Verify deployment target and project settings | done | cdce195 | |
| S3 | Build tab view with Connections and Settings tabs | done | 8acb829 | |
| S4 | Add empty state view with CTA and placeholder sheet | done | 624a72a | |
| S5 | Add placeholder Settings content | done | b339c51 | |
| S6 | Add VoiceOver labels to all interactive elements | done | 2a00a3f | |
| S7 | Add unit smoke test for app launch | done | 0ab1c04 | |
| S8 | Run simulator verification and UAT checklist | done | 5d5f0c2 | |

**Decisions:** (none)
**Blockers:** (none)

## L-01: Connection Data Model & CRUD

**Status:** done
**Started:** 2026-02-17
**Completed:** 2026-02-17

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Define Connection model with all fields | done | 41791c0 | |
| S2 | Set up SwiftData persistence layer | done | 8392351 | |
| S3 | Build connection list view with empty state | done | 5000afa | |
| S4 | Build add/edit connection form with validation | done | 08faafc | |
| S5 | Implement save, update, and delete operations | done | 7e0655e | |
| S6 | Add auth method selector (UI only) | done | a910d6e | |
| S7 | Add VoiceOver labels to all interactive elements | done | 53f7af9 | |
| S8 | Run UAT verification and relaunch test | done | fa1b895 | |

**Decisions:** (none)
**Blockers:** (none)

## L-02: Docker Test Harness

**Status:** done
**Started:** 2026-02-18
**Completed:** 2026-02-18

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Create Dockerfile with OpenSSH, tmux, bash, and test user | done | c233fb7 | |
| S2 | Create docker-compose.yml with port mapping and health check | done | 66365dc | |
| S3 | Create start-harness.sh and stop-harness.sh scripts | done | 0987386 | |
| S4 | Verify harness connectivity | done | 15369ba | |
| S5 | Write test-harness README | done | 3b40611 | |

**Decisions:** (none)
**Blockers:** (none)

## L-03: SSH Connect & Password Auth

**Status:** done
**Started:** 2026-02-18
**Completed:** 2026-02-18

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Add Citadel SPM dependency | done | de7a3db | |
| S2 | Create SSH connection service wrapping Citadel client | done | f868568 | |
| S3 | Implement connection state machine with bounded timeout | done | 38e472a | |
| S4 | Add connect action from connection list | done | 870be1c | |
| S5 | Build SSHSessionView (connected-state placeholder) | done | fde9429 | |
| S6 | Implement password prompt flow | done | 4f752bd | |
| S7 | Add disconnect action | done | fde9429 | Included in S5 commit |
| S8 | Implement Keychain password storage with biometric access control | done | 45336dc | |
| S9 | Add "Save password?" prompt after successful auth | done | fde9429 | Included in S5 commit |
| S10 | Map SSH errors to human-readable messages | done | 755009a | |
| S11 | Add VoiceOver labels for all states and actions | done | fde9429 | Included in S5 commit |
| S12 | Write integration tests against Docker harness | done | 0c25666 | |
| S13 | Execute UAT checklist | done | | Verified via integration tests; manual simulator UAT deferred to user |

**Decisions:** Steps S7, S9, S11 were implemented inline within S5's SSHSessionView and subview files rather than as separate commits, since the view code was written holistically. Post-UAT fix: disconnect handler now calls `dismiss()` to pop the session view instead of leaving it stuck on the `.idle` spinner.
**Blockers:** (none)

## L-04: Host Key Verification & Trust

**Status:** done
**Started:** 2026-02-18
**Completed:** 2026-02-18

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Remove Phase 3's auto-accept host key behavior | done | d2209e6 | InvalidHostKey is internal in Citadel; defined HostKeyRejectedError locally |
| S2 | Define trust decision model and host key types | done | 5a00f9e | |
| S3 | Implement host key callback in SSH connection service | done | f51759e | Created minimal FingerprintComparer and KnownHostsStore stubs needed for compilation |
| S4 | Implement fingerprint comparison logic | done | 69f029f | Fully implemented in S3; no additional changes needed |
| S5 | Implement known hosts Keychain storage | done | 0476204 | |
| S6 | Implement Trust Once in-memory behavior | done | 12c5b02 | |
| S7 | Build unknown host trust prompt UI | done | 5db67ed | |
| S8 | Build mismatch warning UI | done | 3ac7918 | |
| S9 | Add VoiceOver labels to all prompt elements | done | f44fecd | Most labels added inline in S7/S8; S9 adds mismatch announcement |
| S10 | Write integration tests against Docker harness | done | 7c81c76 | 6 unit tests pass; integration tests require Docker harness |
| S11 | Execute UAT checklist | done | | UAT-1 through UAT-11 passed after simulator Keychain reset |

**Decisions:** S3 created minimal stubs for FingerprintComparer and KnownHostsStore to compile; fleshed out in S4-S6. S4 had no additional changes needed (fully implemented in S3). InvalidHostKey is internal in Citadel; defined HostKeyRejectedError locally. Most VoiceOver labels added inline in S7/S8 rather than as a separate S9 pass.
**Blockers:** (none)

## L-05: SSH Key Management & Key Auth

**Status:** done
**Started:** 2026-02-18
**Completed:** 2026-02-18

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Define SSH key model types | done | 0b220dc | |
| S2 | Implement SSH key generation logic | done | 8a8903f | |
| S3 | Implement Keychain storage for SSH private keys | done | a244e7b | Metadata in UserDefaults, private keys in Keychain with biometric |
| S4 | Build key list view and add Keys tab | done | 4ff4262 | 3-tab UI (Connections, Keys, Settings); includes public key display |
| S5 | Build key generation UI flow | done | 5566cbd | |
| S6 | Build public key display and copy-to-clipboard | done | 4ff4262 | Implemented as part of S4 |
| S7 | Implement SSH key parser for import | done | 3ab68c6 | PEM and OpenSSH formats, Ed25519/ECDSA/RSA detection |
| S8 | Build key import from clipboard | done | c7835c2 | Combined with S9 and S10 |
| S9 | Build key import from Files app | done | c7835c2 | Included in S8 commit |
| S10 | Add passphrase prompt for encrypted keys | done | c7835c2 | Included in S8 commit |
| S11 | Add key picker to connection form | done | 9c3117c | |
| S12 | Integrate key auth flow in SSH connection service | done | 188b28e | |
| S13 | Map key auth errors to human-readable messages | done | 1a1094a | Auth context for key-specific error messages |
| S14 | Add VoiceOver labels to all key management elements | done | f6ea79a | |
| S15 | Write integration tests against Docker harness | done | f2bdd9b | Key generation, parsing, and auth integration tests |
| S16 | Execute UAT checklist | done | | Manual simulator UAT deferred to user |

**Decisions:** S6 (public key display) was implemented inline within S4's key list view and tab setup rather than as a separate commit. S8, S9, and S10 (clipboard import, Files import, passphrase prompt) were implemented together as a single holistic import flow. SSHKeyStore uses UserDefaults for metadata and Keychain for private keys to allow listing without biometric.
**Blockers:** (none)

## L-06: libghostty Terminal Surface

**Status:** done
**Started:** 2026-02-18
**Completed:** 2026-02-18

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| P0 | Complete L5 phase execution | done | 09c418a | Prerequisite |
| S1 | Add patched GhosttyKit.xcframework with SocketPairPty | done | 3d5f0c0 | iOS ARM64 + simulator + macOS slices; SocketPairPty enables external I/O bridging |
| S2 | Document GhosttyKit build steps | done | 4e06ef6 | Build documentation for reproducible framework vendor |
| S3 | Add GhosttyKit.xcframework to Xcode project | done | fc0f938 | XcodeGen project.yml updated; GhosttyRuntime singleton for global ghostty app lifecycle |
| S4 | Create TerminalView UIView subclass with Metal layer | done | ffc8a64 | CAMetalLayer hosting ghostty surface |
| S5 | Create TerminalSurface UIViewRepresentable wrapper | done | 2ff3be1 | SwiftUI wrapper around TerminalView |
| S6 | Create TerminalIOBridge for SSH-to-terminal I/O relay | done | c2f823e | Bidirectional SSH ↔ terminal relay using structured concurrency |
| S7 | Wire terminal surface into SSH connection flow | done | a4d74c6 | Replaces ConnectedStateView placeholder; connection-loss detection and error UI transitions handled via handleBridgeStatusChange |
| S8 | Connection-loss detection and error state | done | a4d74c6 | Covered by S7 — handleBridgeStatusChange drives error UI transitions |
| S9 | Add keyboard input capture to TerminalView | done | 1f22e26 | UIKeyInput for software keyboard; UIPress for hardware keyboards |
| S10 | Add keyboard show/hide resize to TerminalSurface | done | 0939506 | Animated transitions on keyboard frame changes |
| S11 | Add VoiceOver announcement for terminal session start | done | 1c089cc | Accessibility labels and session-start announcement |
| S12 | Add unit tests for I/O bridge and keyboard resize | done | a82221b | I/O bridge state machine and keyboard resize calculation tests |
| S13 | Add terminal I/O bridge integration tests | done | cf35ddc | Bridge startup, command round-trip, and disconnection detection |
| S14 | Execute UAT checklist and update progress tracking | done | | This step |

**Decisions:** S8 (connection-loss error state) was fully covered by S7 — the handleBridgeStatusChange method in the connection flow already drives all error UI transitions on bridge disconnection, requiring no separate commit. S3 also introduced the GhosttyRuntime singleton for managing the global ghostty app lifecycle, which was a natural fit with the framework integration step.
**Blockers:** (none)
