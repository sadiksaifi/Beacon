# Phase 3: SSH Connect & Password Auth

## 1. Objective
Enable real SSH connections from the app using password authentication, with clear connection state management, user-initiated disconnect, and secure credential storage.

## 2. Entry Criteria
1. Phase 2 accepted.
2. Docker test harness is running with password auth enabled.
3. At least one saved connection exists from Phase 1.

## 3. Scope In
- Integrate Citadel (SwiftNIO SSH) as SSH library.
- Connect action from saved connection in connection list.
- Password authentication flow (prompt or stored).
- Connection state model: idle, connecting, connected, failed.
- Bounded timeout on connecting state.
- User-initiated disconnect action.
- Credential (password) storage in iOS Keychain.
- `SSHSessionView` placeholder screen (replaced by terminal surface in Phase 6).

## 4. Scope Out
- Host key verification prompts (Phase 4). For this phase, accept all host keys automatically (development convenience; Phase 4 adds proper verification).
- SSH key authentication (Phase 5).
- Terminal display (Phase 6).
- Reconnection logic (Phase 10).

## 5. Product Requirements
- **PR-1:** Add Citadel as SPM dependency.
- **PR-2:** Create a connection service that wraps Citadel's SSH client.
- **PR-3:** Connection service exposes async methods: `connect()`, `disconnect()`, and an observable `status` property.
- **PR-4:** User taps "Connect" on a saved connection to initiate a connection.
- **PR-5:** UI transitions immediately to "Connecting" state on connect tap.
- **PR-6:** If no password is stored: show password prompt (modal sheet with secure text field).
- **PR-7:** If password is stored in Keychain: retrieve and use automatically without prompting.
- **PR-8:** SSH handshake and password auth are attempted using the provided credentials.
- **PR-9:** On success: transition to "Connected" state and show a success indicator.
- **PR-10:** On failure: transition to "Failed" state and show a human-readable error message.
- **PR-11:** Idle — no connection attempt in progress; Connect action is available.
- **PR-12:** Connecting — handshake in progress; Cancel action is available; timeout is configurable with a default of 15 seconds.
- **PR-13:** Connected — SSH session active; Disconnect action is available.
- **PR-14:** Failed — connection attempt failed or connection was lost; error message displayed; Retry action is available.
- **PR-15:** Timeout — if "Connecting" exceeds the timeout, transition to "Failed" with message "Connection timed out."
- **PR-16:** User can tap "Disconnect" while in Connected state.
- **PR-17:** Disconnect sends SSH disconnect message to server.
- **PR-18:** UI transitions to Idle state after disconnect completes.
- **PR-19:** Disconnect action is always visible and reachable when connected.
- **PR-20:** After successful authentication, offer to save password: "Save password for future connections?"
- **PR-21:** If user accepts the save prompt: store password in Keychain keyed to connection ID.
- **PR-22:** If user declines the save prompt: password is used for this session only, not persisted.
- **PR-23:** Stored passwords require biometric or passcode verification to retrieve (Keychain access control).
- **PR-24:** Error "Connection timed out" — could not reach host within timeout.
- **PR-25:** Error "Authentication failed" — password was rejected by server.
- **PR-26:** Error "Connection refused" — server is not accepting connections on this port.
- **PR-27:** Error "Network unavailable" — device has no network connectivity.
- **PR-28:** All errors include a "Try Again" action.

## 6. UX Requirements
- **UX-1:** Connecting state shows an activity indicator with a "Connecting…" message.
- **UX-2:** Password prompt uses a secure text field (dots, not cleartext).
- **UX-3:** "Save password?" prompt appears only after successful auth, never before.
- **UX-4:** Disconnect button is clearly labeled and always accessible when connected.
- **UX-5:** Error messages are written in plain language, not SSH protocol codes.

## 7. Accessibility Requirements
- **A11Y-1:** Connection state changes (connecting, connected, failed) are announced by VoiceOver.
- **A11Y-2:** Connect and Disconnect buttons have descriptive VoiceOver labels.
- **A11Y-3:** Password prompt field has a VoiceOver label describing its purpose.
- **A11Y-4:** Error messages are announced by VoiceOver when they appear.
- **A11Y-5:** All non-terminal text respects Dynamic Type.

## 8. UAT Checklist
- [ ] UAT-1: Tap Connect on a saved connection — confirm "Connecting" state appears.
- [ ] UAT-2: Enter correct password — confirm "Connected" state appears.
- [ ] UAT-3: Decline to save password.
- [ ] UAT-4: Disconnect and reconnect — confirm password prompt appears again.
- [ ] UAT-5: Enter correct password and accept "Save password" — confirm password saves.
- [ ] UAT-6: Disconnect and reconnect — confirm app connects without password prompt (uses Keychain).
- [ ] UAT-7: Enter wrong password — confirm "Authentication failed" error with retry option.
- [ ] UAT-8: Connect to unreachable host — confirm timeout fires and error appears.
- [ ] UAT-9: While connected, tap Disconnect — confirm state returns to Idle.
- [ ] UAT-10: Verify all states are visible (no silent failures).

## 9. Test Allocation
| Type | Scope | Method |
|------|-------|--------|
| Unit | Connection state machine transitions | XCTest |
| Unit | Timeout logic | XCTest |
| Unit | Keychain storage/retrieval (mock) | XCTest |
| Unit | SSH error message mapping | XCTest |
| Critical | Connect + password auth against Docker harness | XCTest (integration) |
| Critical | Disconnect against Docker harness | XCTest (integration) |
| Full | End-to-end UI flow from connection list to connected state | XCUITest (optional) |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. Connection states are deterministic (no ambiguous or stuck states).
3. Timeout prevents indefinite "Connecting" state.
4. Password can be saved to and retrieved from Keychain.
5. Disconnect action works reliably.
6. Known gaps documented before Phase 4.

## 11. Step Sequence

### S1: Add Citadel SPM dependency
- **Complexity:** small
- **Deliverable:** Citadel (SwiftNIO SSH) registered as an SPM dependency in the Xcode project
- **Files:** `Beacon.xcodeproj/project.pbxproj`
- **Depends on:** none
- **Details:** In Xcode, add the Citadel package from its GitHub URL using the SPM package manager. Link the Citadel product to the Beacon app target. Confirm the package resolves and the project builds cleanly with no import errors.
- **Acceptance:**
  - [ ] Citadel package is visible in Xcode's package dependency list
  - [ ] `import Citadel` resolves without error in a Swift source file
  - [ ] Project builds successfully with Citadel linked (PR-1)

### S2: Create SSH connection service wrapping Citadel client
- **Complexity:** large
- **Deliverable:** `SSHConnectionService` — an observable class with async `connect()`, `disconnect()`, and published `status` property
- **Files:** `Beacon/Services/SSHConnectionService.swift`
- **Depends on:** S1
- **Details:** Create `SSHConnectionService` as an `@Observable` class that wraps Citadel's `SSHClient`. Expose `connect(to host: String, port: Int, username: String, password: String) async throws` and `disconnect() async` methods, plus a `status: ConnectionState` published property. Auto-accept all host keys for this phase (Phase 4 adds verification). Keep all Citadel calls off the main thread using async/await.
- **Acceptance:**
  - [ ] `SSHConnectionService` compiles with no errors (PR-2)
  - [ ] `connect()` accepts host, port, username, and password parameters
  - [ ] `disconnect()` is callable and awaitable
  - [ ] `status` is observable from SwiftUI views (PR-3)
  - [ ] Host keys are auto-accepted without prompting (Phase 4 scope out)

### S3: Implement connection state machine with bounded timeout
- **Complexity:** medium
- **Deliverable:** `ConnectionState` enum and state transition logic with 15-second configurable timeout built into `SSHConnectionService`
- **Files:** `Beacon/Models/ConnectionState.swift`, `Beacon/Services/SSHConnectionService.swift` (updated)
- **Depends on:** S2
- **Details:** Define `ConnectionState` as an enum with cases: `.idle`, `.connecting`, `.connected`, `.failed(message: String)`. Implement state transitions in `SSHConnectionService`: idle→connecting on connect call, connecting→connected on success, connecting→failed on error or timeout, connected→idle on disconnect. Add a configurable timeout (default 15 seconds) using a `Task` that races the connection attempt; if the timeout fires first, transition to `.failed(message: "Connection timed out.")` and cancel the connection task.
- **Acceptance:**
  - [ ] `ConnectionState` enum has all four cases (PR-11 through PR-14)
  - [ ] Idle→connecting transition fires on connect call (PR-5)
  - [ ] Connecting→connected transition fires on successful handshake (PR-9)
  - [ ] Connecting→failed transition fires on error (PR-10)
  - [ ] Connecting→failed fires after 15 seconds with "Connection timed out." message (PR-15)
  - [ ] Timeout Task is cancelled if connection succeeds before expiry
  - [ ] Connected→idle transition fires on disconnect (PR-18)

### S4: Add connect action from connection list
- **Complexity:** small
- **Deliverable:** "Connect" button on each connection list row that navigates to `SSHSessionView`
- **Files:** `Beacon/Views/Connections/ConnectionListView.swift` (updated)
- **Depends on:** S3
- **Details:** Add a "Connect" button to each connection list row. Tapping it sets the connection service status to `.connecting` and pushes `SSHSessionView` onto the navigation stack, passing the selected `Connection` so `SSHSessionView` can initiate the SSH handshake. The button should only be available in Idle and Failed states.
- **Acceptance:**
  - [ ] "Connect" button is visible on each connection list row (PR-4)
  - [ ] Tapping "Connect" transitions status to `.connecting` (PR-5)
  - [ ] `SSHSessionView` is pushed with the selected connection

### S5: Build SSHSessionView (connected-state placeholder)
- **Complexity:** medium
- **Deliverable:** `SSHSessionView` — a screen showing all connection states with appropriate actions; serves as the placeholder that Phase 6 replaces with the terminal surface
- **Files:** `Beacon/Views/SSH/SSHSessionView.swift`
- **Depends on:** S4
- **Details:** Build `SSHSessionView` as a SwiftUI view that observes `SSHConnectionService.status` and renders each state: Connecting shows an activity indicator with "Connecting…" message; Connected shows a success indicator (placeholder area for Phase 6) and a Disconnect button; Failed shows the human-readable error message and a "Try Again" button. The view also initiates the connect call on appearance using the passed `Connection`, checking Keychain first before deciding to show the password prompt.
- **Acceptance:**
  - [ ] Connecting state shows activity indicator and "Connecting…" message (UX-1, PR-12)
  - [ ] Connected state shows success indicator and Disconnect button (PR-9, PR-13, PR-19)
  - [ ] Failed state shows error message and "Try Again" button (PR-10, PR-14, PR-28)
  - [ ] View reacts to `ConnectionState` changes in real time

### S6: Implement password prompt flow
- **Complexity:** small
- **Deliverable:** `PasswordPromptView` — modal sheet with secure text field for password entry
- **Files:** `Beacon/Views/SSH/PasswordPromptView.swift`
- **Depends on:** S5
- **Details:** Create a modal sheet presented from `SSHSessionView` when no stored password is found in Keychain. Use a `SecureField` (shows dots, not cleartext) with a descriptive placeholder. Provide "Connect" (confirm) and "Cancel" buttons. If cancelled, abort the SSH flow and transition to `.idle`. If confirmed, pass the entered password to `SSHConnectionService.connect()`.
- **Acceptance:**
  - [ ] Sheet appears when no stored password exists for the connection (PR-6)
  - [ ] Password input uses `SecureField` — shows dots not cleartext (UX-2)
  - [ ] Cancel transitions state to `.idle` and dismisses the sheet
  - [ ] Confirm passes the entered password to the connection service (PR-8)

### S7: Add disconnect action
- **Complexity:** small
- **Deliverable:** Disconnect button in `SSHSessionView` wired to `SSHConnectionService.disconnect()`
- **Files:** `Beacon/Views/SSH/SSHSessionView.swift` (updated)
- **Depends on:** S5
- **Details:** Wire the Disconnect button shown in Connected state to call `SSHConnectionService.disconnect()` asynchronously. After disconnect completes, `status` transitions to `.idle`. The button must remain clearly visible and not require any navigation gesture to reach while in the Connected state.
- **Acceptance:**
  - [ ] Disconnect button is always visible when in `.connected` state (PR-19, UX-4)
  - [ ] Tapping Disconnect calls `SSHConnectionService.disconnect()` (PR-16)
  - [ ] Service sends SSH disconnect message to the server (PR-17)
  - [ ] State transitions to `.idle` after disconnect (PR-18)

### S8: Implement Keychain password storage with biometric access control
- **Complexity:** medium
- **Deliverable:** `KeychainService` — read/write/delete password entries with `.userPresence` biometric access control
- **Files:** `Beacon/Services/KeychainService.swift`
- **Depends on:** S6
- **Details:** Implement `KeychainService` with `store(password:forConnectionID:)`, `retrieve(forConnectionID:) async -> String?`, and `delete(forConnectionID:)` methods. Key each entry using the connection's UUID string. Apply `SecAccessControlCreateWithFlags(.userPresence)` on write so retrieval triggers a biometric or passcode prompt. Handle item-not-found by returning nil. Handle user-cancelled biometric by returning nil and allowing the caller to fall back to the password prompt.
- **Acceptance:**
  - [ ] Password can be stored keyed to a connection ID (PR-21)
  - [ ] Stored password can be retrieved for the same connection ID
  - [ ] Retrieval requires biometric or passcode verification (PR-23)
  - [ ] Item-not-found returns nil (no crash)
  - [ ] User-cancelled biometric returns nil and allows fallback to password prompt

### S9: Add "Save password?" prompt after successful auth
- **Complexity:** small
- **Deliverable:** Post-auth confirmation prompt offering to save the entered password via `KeychainService`
- **Files:** `Beacon/Views/SSH/SSHSessionView.swift` (updated)
- **Depends on:** S8
- **Details:** After `SSHConnectionService.connect()` succeeds, and only if no password was retrieved from Keychain for this session, show a prompt: "Save password for future connections?" with Accept and Decline actions. On Accept, call `KeychainService.store(password:forConnectionID:)`. On Decline, discard the password — it is not persisted. Never show this prompt before authentication or when a Keychain password was already used.
- **Acceptance:**
  - [ ] Prompt appears after successful auth when no stored password was used (PR-20)
  - [ ] Prompt does not appear before authentication (UX-3)
  - [ ] Prompt does not appear when a Keychain password was already used
  - [ ] Accepting stores the password in Keychain (PR-21)
  - [ ] Declining leaves the password unpersisted for this session (PR-22)

### S10: Map SSH errors to human-readable messages
- **Complexity:** small
- **Deliverable:** `SSHErrorMapper` — maps Citadel and network errors to the four user-facing error strings
- **Files:** `Beacon/Utilities/SSHErrorMapper.swift`
- **Depends on:** S3
- **Details:** Create a pure function or namespace that maps SSH-layer errors from Citadel and NWError to the four specified strings: "Connection timed out", "Authentication failed", "Connection refused", "Network unavailable". All unmapped errors fall through to a generic message. Wire this mapper into `SSHConnectionService` so every `.failed` transition carries a user-facing string.
- **Acceptance:**
  - [ ] Timeout error maps to "Connection timed out" (PR-24)
  - [ ] Auth rejection maps to "Authentication failed" (PR-25)
  - [ ] Refused connection maps to "Connection refused" (PR-26)
  - [ ] No network maps to "Network unavailable" (PR-27)
  - [ ] Unknown errors produce a non-empty generic fallback message

### S11: Add VoiceOver labels for all states and actions
- **Complexity:** small
- **Deliverable:** Full accessibility coverage for all SSH connection UI elements
- **Files:** `Beacon/Views/SSH/SSHSessionView.swift` (updated), `Beacon/Views/SSH/PasswordPromptView.swift` (updated), `Beacon/Views/Connections/ConnectionListView.swift` (updated)
- **Depends on:** S9, S10
- **Details:** Add `.accessibilityLabel` to Connect and Disconnect buttons with clear descriptions. Use `AccessibilityNotification.announcement` to announce state transitions (connecting, connected, failed). Label the `SecureField` in `PasswordPromptView` with its purpose. Ensure error text is in the accessibility tree so VoiceOver announces it on appearance. Verify all text uses Dynamic Type-compatible font styles.
- **Acceptance:**
  - [ ] State changes (connecting, connected, failed) are announced by VoiceOver (A11Y-1)
  - [ ] Connect and Disconnect buttons have descriptive VoiceOver labels (A11Y-2)
  - [ ] Password `SecureField` has a VoiceOver label (A11Y-3)
  - [ ] Error messages are announced by VoiceOver when they appear (A11Y-4)
  - [ ] All non-terminal text respects Dynamic Type (A11Y-5)

### S12: Write integration tests against Docker harness
- **Complexity:** medium
- **Deliverable:** XCTest integration tests for connect + password auth and disconnect, runnable against the local Docker test harness
- **Files:** `BeaconTests/SSHConnectionTests.swift`
- **Depends on:** S11
- **Details:** Write XCTest tests that instantiate `SSHConnectionService` and connect to the Docker harness at `localhost:2222` using the documented test credentials. Verify the state machine transitions through `.connecting` → `.connected`. Write a second test that calls `disconnect()` and verifies the transition to `.idle`. Mark these as the Critical test lane. Guard each test with a precondition check for harness availability and skip gracefully if not reachable.
- **Acceptance:**
  - [ ] Test file builds as part of the BeaconTests target
  - [ ] Connect + password auth test passes against the running Docker harness
  - [ ] Disconnect test passes against the running Docker harness
  - [ ] Tests skip gracefully when Docker harness is not reachable

### S13: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** Verified UAT pass on simulator against the Docker test harness
- **Files:** none (verification step)
- **Depends on:** S12
- **Details:** Walk through all 10 UAT checklist items on the iOS simulator with the Docker harness running. Verify state transitions, the full password save/retrieve round-trip, error cases (wrong password, unreachable host), and the disconnect flow. Document any deviations or known gaps before starting Phase 4.
- **Acceptance:**
  - [ ] All UAT checklist items (UAT-1 through UAT-10) pass
  - [ ] No crashes or stuck connection states observed
  - [ ] Known gaps documented before Phase 4

## 12. References
- [ssh-library-decision.md](../refs/ssh-library-decision.md)
- [security-architecture.md](../refs/security-architecture.md)
