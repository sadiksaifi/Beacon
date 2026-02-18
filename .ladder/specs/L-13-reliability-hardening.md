# Phase 13: Reliability Hardening

## 1. Objective
Eliminate silent failures, enforce bounded timeouts on all async operations, and provide human-readable error messages for every failure class so that no state in the app can hang or leave the user stranded.

## 2. Entry Criteria
1. Phase 12 accepted.
2. All core workflows are functional (SSH, terminal, tmux, lifecycle).

## 3. Scope In
1. Map all internal transport/channel error codes to human-readable messages.
2. Enforce bounded timeouts on ALL connection and channel states.
3. Deterministic state machine: no ambiguous states, no silent hangs, no dead-end screens.
4. Network condition awareness (NWPathMonitor: WiFi vs cellular vs none) with appropriate messaging.
5. Security failure messages remain explicit and unambiguous.
6. Audit every screen for dead-end states (no screen should lack a next action).

## 4. Scope Out
1. Multi-endpoint failover.
2. Background reconnect daemon.
3. Crash reporting infrastructure (separate concern).

## 5. Product Requirements
- **PR-1:** Every SSH/transport error code from Citadel has a corresponding human-readable message.
- **PR-2:** Error messages describe what happened and suggest exactly one user action (retry, reconnect, check settings, etc.).
- **PR-3:** Raw error codes, stack traces, and developer jargon are never shown to the user.
- **PR-4:** Connection attempts have a bounded timeout (default 15 seconds, configurable in Phase 14).
- **PR-5:** Channel open requests have a bounded timeout (10 seconds).
- **PR-6:** SSH authentication has a bounded timeout (30 seconds, to allow biometric prompt).
- **PR-7:** tmux command execution has a bounded timeout (5 seconds for list/create/attach).
- **PR-8:** Reconnect attempts have a bounded timeout (15 seconds).
- **PR-9:** All timeouts transition to a Failed state with a descriptive message.
- **PR-10:** No timer, spinner, or loading state may persist indefinitely.
- **PR-11:** Every connection state has clear entry conditions, clear exit conditions (success AND failure paths), and a visible user action (connect, disconnect, retry, cancel, go back).
- **PR-12:** No state allows the app to hang — every state either resolves or times out.
- **PR-13:** The complete connection lifecycle state machine is documented as a Mermaid diagram.
- **PR-14:** NWPathMonitor (from Phase 10) provides network context in error messages.
- **PR-15:** If network is unavailable and user tries to connect: "No network connection — connect to WiFi or cellular data."
- **PR-16:** If network changes during connection: handle gracefully (reconnect or inform user).
- **PR-17:** Cellular network requires no special warning (cellular is fine for SSH), but network type is noted in diagnostics.
- **PR-18:** Every screen in the app is audited for dead-end states (a dead-end is any screen where the user has no visible action to proceed or go back).
- **PR-19:** Every error screen has at least one action: retry, go back, or reconnect.
- **PR-20:** Every loading/connecting screen has a cancel action.
- **PR-21:** Every success screen has a clear next step or auto-dismisses.

## 6. UX Requirements
- **UX-1:** Error messages use plain language — no protocol codes, no stack traces, no developer jargon.
- **UX-2:** Every error includes a suggestion or action.
- **UX-3:** Loading states always indicate what is happening and provide a cancel/back option.
- **UX-4:** Network status changes are communicated via inline banners, not blocking alerts.

## 7. Accessibility Requirements
- **A11Y-1:** Error messages are announced by VoiceOver.
- **A11Y-2:** Error action buttons (retry, reconnect, go back) have descriptive VoiceOver labels.
- **A11Y-3:** Timeout transitions are announced by VoiceOver.
- **A11Y-4:** Network status banners are VoiceOver-accessible.

## 8. UAT Checklist
- [ ] UAT-1: Connect to unreachable host — confirm timeout fires within expected window and message is clear.
- [ ] UAT-2: Connect with wrong password — confirm "Authentication failed" with retry option.
- [ ] UAT-3: Connect successfully, then stop Docker harness — confirm disconnect is detected with reconnect option.
- [ ] UAT-4: Disable network on device, attempt connect — confirm "No network" message.
- [ ] UAT-5: Connect, disable network — confirm connection loss is detected and message appears.
- [ ] UAT-6: Re-enable network — confirm reconnect is available.
- [ ] UAT-7: Navigate every screen in the app — confirm no screen is a dead-end (every screen has a next action).
- [ ] UAT-8: Trigger a tmux command failure — confirm clear error message (not raw error).
- [ ] UAT-9: Verify all error messages are written in plain language.
- [ ] UAT-10: Verify all loading/connecting states have a cancel or back action.

## 9. Test Allocation

| Type | Scope | Method |
|------|-------|--------|
| Unit | Error message mapping (every error code maps to a message) | XCTest |
| Unit | Timeout enforcement logic (timers fire, states transition) | XCTest |
| Unit | State machine transition coverage (entry/exit/failure paths) | XCTest |
| Integration | Timeout scenario (connect to unreachable host, verify timeout) | XCTest + Docker harness |
| Integration | Reconnect after disconnect (server kill, verify reconnect flow) | XCTest + Docker harness |
| E2E | Fault injection suite (network loss, server kill, auth failure combos) | XCUITest + Docker harness |

## 10. Exit Criteria
1. UAT checklist items pass.
2. No state in the app can hang indefinitely.
3. Every error displays a human-readable message with a next action.
4. All timeouts are bounded and documented.
5. No dead-end screens exist.
6. Known gaps documented before Phase 14.

## 11. Step Sequence

### S1: Create error message catalogue for all Citadel transport errors
- **Complexity:** medium
- **Deliverable:** An enum/struct mapping every SSH/transport error code to a user-facing message with a suggested action
- **Files:** `Beacon/Features/Connection/SSHErrorMessages.swift`
- **Depends on:** none
- **Details:** Enumerate all error types from Citadel's SSH transport and channel layers (connection refused, timeout, auth failure, host key mismatch, channel open failure, unexpected disconnect, etc.). Create a mapping that converts each into a human-readable message with exactly one suggested action. Ensure raw error codes and stack traces are never surfaced to the user. Include example messages like "Connection timed out — check that the server address and port are correct."
- **Acceptance:**
  - [ ] Every Citadel SSH error type has a corresponding human-readable message
  - [ ] Each message includes exactly one user action (retry, reconnect, check settings, etc.)
  - [ ] No raw error codes or developer jargon appear in any message
  - [ ] Error mapping is used by all error display paths in the app

### S2: Enforce bounded timeouts on all async operations
- **Complexity:** large
- **Deliverable:** Timeout wrappers on all connection, channel, auth, tmux, and reconnect operations
- **Files:** `Beacon/Features/Connection/SSHConnectionManager.swift`, `Beacon/Features/Connection/SSHChannelManager.swift`, `Beacon/Features/Tmux/TmuxService.swift`, `Beacon/Features/Connection/ReconnectManager.swift`
- **Depends on:** S1
- **Details:** Audit every async operation across the connection lifecycle. Add bounded timeouts: connection attempt (15s), channel open (10s), SSH auth (30s), tmux commands (5s), reconnect (15s). Every timeout transitions the operation to a Failed state with a descriptive message from the S1 error catalogue. Ensure no spinner, timer, or loading state can persist indefinitely — all must resolve or time out.
- **Acceptance:**
  - [ ] Connection attempt times out at 15 seconds
  - [ ] Channel open times out at 10 seconds
  - [ ] SSH authentication times out at 30 seconds
  - [ ] tmux commands time out at 5 seconds
  - [ ] Reconnect attempt times out at 15 seconds
  - [ ] All timeouts transition to Failed state with descriptive message
  - [ ] No loading state can persist indefinitely

### S3: Audit and document connection state machine
- **Complexity:** medium
- **Deliverable:** Verified state machine with clear entry/exit conditions for every state, plus a Mermaid diagram
- **Files:** `Beacon/Features/Connection/ConnectionState.swift`, `.ladder/specs/L-13-reliability-hardening.md`
- **Depends on:** S2
- **Details:** Audit the existing connection state enum for completeness. Verify every state has clear entry conditions, exit conditions (both success and failure paths), and a visible user action. Ensure no state allows the app to hang — every state must resolve or time out. Add a Mermaid stateDiagram to this spec documenting the complete connection lifecycle.
- **Acceptance:**
  - [ ] Every state has documented entry conditions
  - [ ] Every state has documented exit conditions (success AND failure)
  - [ ] Every state has a visible user action
  - [ ] Mermaid state diagram is added to this spec file
  - [ ] No state can hang indefinitely

### S4: Audit all screens for dead-end states and add missing actions
- **Complexity:** medium
- **Deliverable:** All screens have at least one user action; no screen is a dead end
- **Files:** `Beacon/Features/Connection/ConnectionView.swift`, `Beacon/Features/Terminal/TerminalView.swift`, `Beacon/Features/Tmux/TmuxSessionView.swift`
- **Depends on:** S1
- **Details:** Walk through every screen and state in the app. Verify every error screen has at least one action (retry, go back, reconnect). Verify every loading/connecting screen has a cancel action. Verify every success screen has a clear next step or auto-dismisses. Add missing actions where gaps are found.
- **Acceptance:**
  - [ ] Every error screen has at least one action button
  - [ ] Every loading/connecting screen has a cancel/back action
  - [ ] Every success screen has a next step or auto-dismisses
  - [ ] No screen in the app is a dead-end

### S5: Integrate NWPathMonitor context into error messages
- **Complexity:** small
- **Deliverable:** Error messages include network context when relevant (no network, WiFi, cellular)
- **Files:** `Beacon/Features/Connection/SSHErrorMessages.swift`, `Beacon/Features/Connection/NetworkMonitor.swift`
- **Depends on:** S1
- **Details:** Use the NWPathMonitor from Phase 10 to enrich error messages with network context. If the network is unavailable when a connection fails, show "No network connection — connect to WiFi or cellular data" instead of a generic timeout message. If network changes during an active connection, inform the user or trigger reconnect. Cellular requires no special warning but network type is available for diagnostics.
- **Acceptance:**
  - [ ] "No network" message appears when network is unavailable and user tries to connect
  - [ ] Network loss during connection is detected and messaged
  - [ ] Network status uses inline banners, not blocking alerts
  - [ ] Cellular connections show no special warning

### S6: Add VoiceOver announcements for errors, timeouts, and network banners
- **Complexity:** small
- **Deliverable:** VoiceOver announces error messages, timeout transitions, and network status changes
- **Files:** `Beacon/Features/Connection/ConnectionView.swift`, `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S4, S5
- **Details:** Post VoiceOver announcements via `UIAccessibility.post(notification: .announcement, argument:)` for all error messages, timeout transitions, and network status banner changes. Ensure error action buttons (retry, reconnect, go back) have descriptive accessibility labels.
- **Acceptance:**
  - [ ] Error messages trigger VoiceOver announcements
  - [ ] Timeout transitions trigger VoiceOver announcements
  - [ ] Network status banners are VoiceOver-accessible
  - [ ] Action buttons have descriptive VoiceOver labels

### S7: Review security-related error messages for explicitness
- **Complexity:** small
- **Deliverable:** Confirmation that all security errors (host key mismatch, auth failure, key issues) are explicit and unambiguous
- **Files:** `Beacon/Features/Connection/SSHErrorMessages.swift`
- **Depends on:** S1
- **Details:** Review all security-related error messages from the S1 catalogue. Verify host key verification failure, authentication failure, key format errors, and permission errors all provide clear, explicit messaging. Security errors must never be vague or misleading — the user must understand what failed and why. Adjust any messages that are ambiguous.
- **Acceptance:**
  - [ ] Host key verification failure message is explicit and unambiguous
  - [ ] Authentication failure message clearly states the cause
  - [ ] Key-related error messages are clear and actionable
  - [ ] No security error is vague or misleading

### S8: Write unit and integration tests for error mapping and timeouts
- **Complexity:** medium
- **Deliverable:** Unit tests for error mapping and timeout logic; integration tests for timeout and reconnect scenarios
- **Files:** `BeaconTests/Features/Connection/SSHErrorMessagesTests.swift`, `BeaconTests/Features/Connection/TimeoutTests.swift`
- **Depends on:** S2, S3
- **Details:** Unit tests: verify every error code maps to a human-readable message, verify timeout enforcement logic fires at correct intervals and transitions to Failed state, verify state machine transitions cover all entry/exit/failure paths. Integration tests against Docker harness: verify connection timeout scenario (unreachable host), verify reconnect-after-disconnect flow.
- **Acceptance:**
  - [ ] Unit tests cover every error code → message mapping
  - [ ] Unit tests verify timeout logic for all operation types
  - [ ] Unit tests cover state machine transition paths
  - [ ] Integration test passes for timeout scenario against Docker harness
  - [ ] Integration test passes for reconnect-after-disconnect against Docker harness

### S9: Test error and network fault scenarios against Docker harness
- **Complexity:** medium
- **Deliverable:** All error scenarios verified against Docker harness with fault injection
- **Files:** `BeaconTests/Integration/ReliabilityTests.swift`
- **Depends on:** S8
- **Details:** Run fault injection scenarios against the Docker harness: wrong password auth failure, unreachable host timeout, server kill during session, network loss simulation, tmux command failure. Verify each scenario produces the correct human-readable error message with an appropriate action. Test network change scenarios if possible on device (disable WiFi, switch to cellular).
- **Acceptance:**
  - [ ] Wrong password produces "Authentication failed" with retry option
  - [ ] Unreachable host produces timeout message within expected window
  - [ ] Server kill produces disconnect message with reconnect option
  - [ ] tmux command failure produces clear error (not raw error)
  - [ ] All error messages are plain language with user actions
