# Phase 11: tmux Core (List, Create, Attach, Detach)

## 1. Objective
Support core tmux workflows: list existing sessions, create new sessions, attach to a session, and detach from an active session.

## 2. Entry Criteria
1. Phase 10 accepted.
2. iOS lifecycle and reconnection are functional.
3. Docker harness has tmux installed and available.

## 3. Scope In
1. tmux session sheet accessible from terminal UI.
2. List existing tmux sessions with refresh.
3. Create a named session with name validation.
4. Attach to a selected session (terminal enters tmux context).
5. Detach from active tmux session.
6. Empty state explaining tmux for first-time users.
7. Session errors shown in-context.

## 4. Scope Out
1. tmux pane/window management (split panes, multiple windows).
2. tmux control mode (programmatic control).
3. Cross-host tmux orchestration.
4. tmux reconnect/reattach after backgrounding (Phase 12).

## 5. Product Requirements
- **PR-1:** "Sessions" button in the terminal toolbar opens the tmux session sheet.
- **PR-2:** Sheet overlays the terminal view without losing connection context.
- **PR-3:** Sheet can be dismissed to return to the active terminal.
- **PR-4:** Sheet loads the list of existing tmux sessions on open by executing `tmux list-sessions` via the SSH channel.
- **PR-5:** Each session row shows: session name, number of windows, creation time or attached status.
- **PR-6:** Pull-to-refresh or refresh button reloads the session list.
- **PR-7:** If no sessions exist, show empty state: "No tmux sessions. Create one to keep your work running even when you disconnect."
- **PR-8:** "New Session" action is visible in the sheet.
- **PR-9:** User enters a session name; validation rejects empty names, duplicate names (warn if exists), and special characters that tmux rejects.
- **PR-10:** Creation executes `tmux new-session -d -s [name]` via SSH channel.
- **PR-11:** On successful creation: session appears in list, user can attach immediately.
- **PR-12:** On creation failure: error message shown in-context within the sheet.
- **PR-13:** User taps a session in the list to attach; attach executes `tmux attach-session -t [name]` via SSH channel.
- **PR-14:** Terminal enters tmux context — tmux output renders in the libghostty surface.
- **PR-15:** Sheet dismisses after successful attach.
- **PR-16:** If attach fails (e.g., session was deleted between list and attach), show error in sheet.
- **PR-17:** While attached to a tmux session, a "Detach" action is available (button in toolbar or keyboard shortcut Ctrl+B, D).
- **PR-18:** Detach executes tmux detach (or sends the tmux prefix + d key sequence).
- **PR-19:** Terminal returns to the base shell (no longer in tmux context) after detach.
- **PR-20:** Session continues running on the server after detach.
- **PR-21:** If tmux is not installed on the remote server: show clear message "tmux is not available on this server."
- **PR-22:** If session list fails to load: show error with retry option.
- **PR-23:** If create/attach/detach fails: show error in-context (in the sheet or as a banner), not a blocking alert.

## 6. UX Requirements
- **UX-1:** tmux sheet does not break the connection or terminal context.
- **UX-2:** Empty state is friendly and educational — explains what tmux is and why it's useful.
- **UX-3:** Attaching to a session feels like switching context, not starting fresh.
- **UX-4:** Detach returns to a clean base shell state.
- **UX-5:** Errors do not require dismissing multiple modals.

## 7. Accessibility Requirements
- **A11Y-1:** Sessions button has VoiceOver label: "tmux sessions."
- **A11Y-2:** Session list items have VoiceOver labels: "[session name], [number] windows."
- **A11Y-3:** Create, Attach, and Detach actions have descriptive VoiceOver labels.
- **A11Y-4:** Empty state text and error messages are VoiceOver-readable.
- **A11Y-5:** All text respects Dynamic Type.

## 8. UAT Checklist
- [ ] UAT-1: Connect to Docker harness — confirm terminal is active.
- [ ] UAT-2: Open tmux session sheet — confirm it opens without breaking connection.
- [ ] UAT-3: Verify empty state shows explanation (if no sessions exist).
- [ ] UAT-4: Create a new session named "test" — confirm it appears in list.
- [ ] UAT-5: Attach to "test" session — confirm terminal shows tmux context.
- [ ] UAT-6: Run a command inside tmux (e.g., `echo "in tmux"`).
- [ ] UAT-7: Detach from session — confirm terminal returns to base shell.
- [ ] UAT-8: Re-open session sheet — confirm "test" session still exists.
- [ ] UAT-9: Attach to "test" again — confirm previous tmux state is present.
- [ ] UAT-10: Attempt to create a session with an empty name — confirm validation error.
- [ ] UAT-11: Attempt to create a session with a duplicate name — confirm warning.
- [ ] UAT-12: Connect to a server without tmux — confirm "tmux not available" message.

## 9. Test Allocation

| Type | Scope | Method |
|------|-------|--------|
| Unit | TmuxSessionParser (list-sessions output parsing) | XCTest |
| Unit | TmuxSessionNameValidator (empty, duplicate, special chars) | XCTest |
| Unit | TmuxCommandBuilder (list, new-session, attach, detach commands) | XCTest |
| Unit | TmuxAvailabilityChecker (installed vs not-installed detection) | XCTest |
| Integration | List/create/attach/detach happy path | XCTest + Docker harness |
| E2E | Full tmux session lifecycle UI flow (optional) | XCUITest + Docker harness |

## 10. Exit Criteria
1. UAT checklist items pass.
2. tmux list/create/attach/detach workflow is functional.
3. Detach leaves session running on server.
4. Errors are visible and actionable.
5. Known gaps documented before Phase 12.

## 11. Step Sequence

### S1: Add tmux session sheet entry point
- **Complexity:** small
- **Deliverable:** "Sessions" button in terminal toolbar that presents the tmux session sheet
- **Files:** `Beacon/Features/Tmux/TmuxSessionSheet.swift`, `Beacon/Features/Terminal/TerminalToolbar.swift`
- **Depends on:** none
- **Details:** Add a "Sessions" button to the terminal toolbar. Tapping it presents a SwiftUI sheet. The sheet initially shows a loading state. Dismissing the sheet returns to the terminal without interrupting the SSH connection.
- **Acceptance:**
  - [ ] Sessions button is visible in terminal toolbar
  - [ ] Tapping button presents a sheet overlay
  - [ ] Dismissing sheet returns to terminal without dropping connection

### S2: Implement session list retrieval via `tmux list-sessions`
- **Complexity:** medium
- **Deliverable:** Service that executes `tmux list-sessions` over SSH and returns raw output
- **Files:** `Beacon/Features/Tmux/TmuxService.swift`
- **Depends on:** S1
- **Details:** Create a TmuxService that takes an SSH channel reference and executes `tmux list-sessions -F '#{session_name}:#{session_windows}:#{session_created}:#{session_attached}'`. Return the raw string output or an error if the command fails. Handle the case where tmux is not installed (command not found).
- **Acceptance:**
  - [ ] TmuxService executes `tmux list-sessions` via SSH channel
  - [ ] Raw output is returned on success
  - [ ] Error is returned if command fails

### S3: Parse session list output into structured data
- **Complexity:** small
- **Deliverable:** Parser that converts `tmux list-sessions` output into an array of TmuxSession models
- **Files:** `Beacon/Features/Tmux/TmuxSessionParser.swift`, `Beacon/Features/Tmux/TmuxSession.swift`
- **Depends on:** S2
- **Details:** Define a TmuxSession model with properties: name, windowCount, createdAt, isAttached. Parse the formatted output line-by-line into TmuxSession instances. Handle malformed lines gracefully by skipping them.
- **Acceptance:**
  - [ ] TmuxSession model has name, windowCount, createdAt, isAttached properties
  - [ ] Parser correctly splits formatted output into TmuxSession array
  - [ ] Malformed lines are skipped without crashing

### S4: Build session list UI with empty state
- **Complexity:** medium
- **Deliverable:** SwiftUI list view showing sessions or empty state message
- **Files:** `Beacon/Features/Tmux/TmuxSessionSheet.swift`, `Beacon/Features/Tmux/TmuxSessionRow.swift`
- **Depends on:** S3
- **Details:** Populate the session sheet with a List of TmuxSessionRow views. Each row shows session name, window count, and attached status. Add pull-to-refresh that re-invokes TmuxService. When the session array is empty, show the empty state message explaining tmux.
- **Acceptance:**
  - [ ] Session list displays rows with name, window count, and status
  - [ ] Pull-to-refresh reloads the session list
  - [ ] Empty state message displays when no sessions exist

### S5: Implement create session with name validation
- **Complexity:** medium
- **Deliverable:** "New Session" flow with name input, validation, and `tmux new-session` execution
- **Files:** `Beacon/Features/Tmux/TmuxSessionSheet.swift`, `Beacon/Features/Tmux/TmuxSessionNameValidator.swift`, `Beacon/Features/Tmux/TmuxService.swift`
- **Depends on:** S4
- **Details:** Add a "New Session" button to the sheet. Present a name input field. Validate the name: reject empty, reject duplicates against loaded session list, reject characters tmux disallows (colons, periods, dots at start). On valid name, execute `tmux new-session -d -s [name]` via TmuxService. On success, refresh the list. On failure, show error inline.
- **Acceptance:**
  - [ ] "New Session" button is visible in the sheet
  - [ ] Empty name is rejected with validation error
  - [ ] Duplicate name shows warning
  - [ ] Invalid characters are rejected
  - [ ] Successful creation refreshes the session list
  - [ ] Failed creation shows error in-context

### S6: Implement attach to session
- **Complexity:** medium
- **Deliverable:** Tapping a session row attaches to that tmux session in the terminal
- **Files:** `Beacon/Features/Tmux/TmuxSessionSheet.swift`, `Beacon/Features/Tmux/TmuxService.swift`
- **Depends on:** S4
- **Details:** When the user taps a session row, execute `tmux attach-session -t [name]` via the SSH channel. This sends the command to the terminal's PTY so tmux output renders in the libghostty surface. Dismiss the sheet on success. If attach fails, show error in the sheet.
- **Acceptance:**
  - [ ] Tapping a session row sends attach command to SSH channel
  - [ ] Terminal renders tmux output after attach
  - [ ] Sheet dismisses on successful attach
  - [ ] Error shown in sheet if attach fails

### S7: Implement detach from session
- **Complexity:** small
- **Deliverable:** "Detach" action that exits the tmux session and returns to base shell
- **Files:** `Beacon/Features/Terminal/TerminalToolbar.swift`, `Beacon/Features/Tmux/TmuxService.swift`
- **Depends on:** S6
- **Details:** When the user is attached to a tmux session, show a "Detach" button in the terminal toolbar. Tapping it sends the tmux prefix + d key sequence (Ctrl+B, D) to the terminal. The terminal returns to the base shell. The tmux session remains running on the server.
- **Acceptance:**
  - [ ] "Detach" button appears in toolbar when in tmux context
  - [ ] Tapping Detach sends prefix + d key sequence
  - [ ] Terminal returns to base shell after detach
  - [ ] tmux session continues running on server

### S8: Handle tmux-not-installed case
- **Complexity:** small
- **Deliverable:** Detection of missing tmux binary and user-facing message
- **Files:** `Beacon/Features/Tmux/TmuxService.swift`, `Beacon/Features/Tmux/TmuxSessionSheet.swift`
- **Depends on:** S2
- **Details:** When TmuxService receives a "command not found" or exit code 127 from the `tmux list-sessions` call, surface a specific error state in the sheet: "tmux is not available on this server." This replaces the session list entirely — do not show create/attach actions.
- **Acceptance:**
  - [ ] "command not found" / exit code 127 is detected
  - [ ] Sheet shows "tmux is not available on this server." message
  - [ ] Create/attach actions are hidden when tmux is unavailable

### S9: Add error handling for list/create/attach/detach failures
- **Complexity:** medium
- **Deliverable:** In-context error display for all tmux operations
- **Files:** `Beacon/Features/Tmux/TmuxSessionSheet.swift`, `Beacon/Features/Tmux/TmuxService.swift`
- **Depends on:** S5, S6, S7, S8
- **Details:** For each TmuxService operation, catch errors and display them in-context within the sheet or as a banner overlay. List failures show a retry option. Create/attach/detach failures show the error message inline. Errors never require dismissing multiple modals.
- **Acceptance:**
  - [ ] List failure shows error with retry option
  - [ ] Create failure shows error inline in the sheet
  - [ ] Attach failure shows error inline in the sheet
  - [ ] Detach failure shows error as banner
  - [ ] No errors require dismissing multiple modals

### S10: Add VoiceOver labels
- **Complexity:** small
- **Deliverable:** Accessibility labels and Dynamic Type support across all tmux UI
- **Files:** `Beacon/Features/Tmux/TmuxSessionSheet.swift`, `Beacon/Features/Tmux/TmuxSessionRow.swift`, `Beacon/Features/Terminal/TerminalToolbar.swift`
- **Depends on:** S9
- **Details:** Add `.accessibilityLabel("tmux sessions")` to the Sessions button. Add labels to session rows: "[name], [N] windows." Add labels to Create, Attach, and Detach actions. Ensure empty state and error messages are VoiceOver-readable. Verify all text respects Dynamic Type.
- **Acceptance:**
  - [ ] Sessions button has VoiceOver label "tmux sessions"
  - [ ] Session rows announce name and window count
  - [ ] Create, Attach, Detach actions have descriptive labels
  - [ ] Empty state and errors are VoiceOver-readable
  - [ ] All text respects Dynamic Type

### S11: Test against Docker harness
- **Complexity:** medium
- **Deliverable:** Unit and integration tests for tmux parsing, validation, and command execution
- **Files:** `BeaconTests/Features/Tmux/TmuxSessionParserTests.swift`, `BeaconTests/Features/Tmux/TmuxSessionNameValidatorTests.swift`, `BeaconTests/Features/Tmux/TmuxServiceTests.swift`
- **Depends on:** S9
- **Details:** Write unit tests for TmuxSessionParser (valid output, empty output, malformed lines), TmuxSessionNameValidator (empty, duplicate, invalid chars, valid names), and TmuxCommandBuilder. Write integration tests that run list/create/attach/detach against the Docker harness.
- **Acceptance:**
  - [ ] Parser tests cover valid, empty, and malformed output
  - [ ] Validator tests cover empty, duplicate, invalid chars, and valid names
  - [ ] Integration tests pass against Docker harness for list/create/attach/detach

### S12: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** All UAT checklist items verified and passing
- **Files:** none (manual verification)
- **Depends on:** S11
- **Details:** Walk through every item in the UAT checklist (UAT-1 through UAT-12) against the Docker harness. Document any failures and fix before marking phase complete.
- **Acceptance:**
  - [ ] All 12 UAT checklist items pass
  - [ ] Any failures found are fixed and re-verified
