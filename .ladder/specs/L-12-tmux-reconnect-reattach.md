# Phase 12: tmux Reconnect & Reattach

## 1. Objective
After a disconnect and reconnect, automatically detect and reattach to the user's previous tmux session for seamless session continuity.

## 2. Entry Criteria
1. Phase 11 accepted.
2. tmux list/create/attach/detach is functional.
3. iOS lifecycle reconnection (Phase 10) is functional.

## 3. Scope In
1. Track which tmux session was active before disconnect.
2. After reconnect, auto-detect if the previous tmux session still exists.
3. If it exists: auto-reattach. Terminal content is restored by tmux screen redraw.
4. If it doesn't exist: show clear message, return to base shell.
5. Seamless experience: user backgrounds, returns, and is back in their tmux session.

## 4. Scope Out
1. Persisting tmux session across server reboots (tmux limitation).
2. tmux resurrect/continuum plugin integration.
3. Multiple tmux session tracking (track only the most recent).

## 5. Product Requirements
- **PR-1:** When user attaches to a tmux session (Phase 11), record the session name in-memory.
- **PR-2:** When user detaches voluntarily, clear the tracked session name.
- **PR-3:** When connection is lost (involuntary disconnect), preserve the tracked session name.
- **PR-4:** After successful reconnect (Phase 10), check if a tmux session name is tracked.
- **PR-5:** If tracked, execute `tmux has-session -t [name]` to verify session exists.
- **PR-6:** If session exists, execute `tmux attach-session -t [name]` automatically.
- **PR-7:** tmux redraws the terminal content — this replaces the display snapshot from Phase 10.
- **PR-8:** Show transient toast banner: "Reattached to tmux session '[name]'". Auto-dismisses after ~3 seconds.
- **PR-9:** If session does not exist, clear tracked session and show message: "Your tmux session '[name]' is no longer available."
- **PR-10:** Terminal remains on the base shell and ready for use when reattach is not possible.
- **PR-11:** If `tmux attach-session` fails (race condition, server issue), show error and clear tracked session.
- **PR-12:** User can manually open the tmux session sheet to manage sessions after a failed reattach.
- **PR-13:** No automatic retry loop for reattach — one attempt per reconnect.

## 6. UX Requirements
- **UX-1:** Reattach is automatic — user does not need to manually navigate to tmux sessions.
- **UX-2:** Terminal content visually transitions from snapshot to live tmux (may be a brief flicker as tmux redraws).
- **UX-3:** If reattach is not possible, messaging is clear and non-alarming.
- **UX-4:** User is never left in a confusing state (attached to wrong session, blank screen, etc.).

## 7. Accessibility Requirements
- **A11Y-1:** Reattach toast banner is announced by VoiceOver.
- **A11Y-2:** "Session no longer available" message is announced by VoiceOver.

## 8. UAT Checklist
- [ ] UAT-1: Connect and create a tmux session named "persist".
- [ ] UAT-2: Attach to "persist" and run `echo "still here"`.
- [ ] UAT-3: Background the app. Wait 10+ seconds.
- [ ] UAT-4: Return to Beacon — confirm reconnect happens (Phase 10 behavior).
- [ ] UAT-5: Confirm auto-reattach to "persist" session occurs.
- [ ] UAT-6: Confirm terminal shows tmux content (including previous output).
- [ ] UAT-7: Run another command — confirm terminal is live in tmux context.
- [ ] UAT-8: Background, wait, return — confirm reattach works again.
- [ ] UAT-9: Background the app. While backgrounded, kill the tmux session on the server (`tmux kill-session -t persist`).
- [ ] UAT-10: Return to Beacon — confirm reconnect happens.
- [ ] UAT-11: Confirm "Session 'persist' is no longer available" message appears.
- [ ] UAT-12: Confirm terminal is on base shell and usable.

## 9. Test Allocation

| Type | Scope | Method |
|------|-------|--------|
| Unit | TmuxSessionTracker (save, clear, preserve on disconnect) | XCTest |
| Unit | Reattach state machine (tracked → check → attach/gone) | XCTest |
| Unit | Session existence check logic (has-session parsing) | XCTest |
| Integration | Background → reconnect → reattach happy path | XCTest + Docker harness |
| Integration | Background → reconnect → session-gone scenario | XCTest + Docker harness |
| E2E | Full lifecycle cycle (optional) | XCUITest + Docker harness |

## 10. Exit Criteria
1. UAT checklist items pass.
2. Auto-reattach works for standard background/foreground cycle with active tmux session.
3. Session-gone case is handled cleanly.
4. No confusing or dead-end states after reattach.
5. Known gaps documented before Phase 13.

## 11. Step Sequence

### S1: Create TmuxSessionTracker with in-memory session tracking
- **Complexity:** small
- **Deliverable:** A tracker class that stores the active tmux session name in-memory
- **Files:** `Beacon/Features/Tmux/TmuxSessionTracker.swift`
- **Depends on:** none
- **Details:** Create a TmuxSessionTracker class with a published optional `activeSessionName` property. Provide methods: `trackSession(_ name: String)`, `clearTrackedSession()`, and a read-only `trackedSessionName`. The tracker is in-memory only — state is lost on app termination, which is acceptable since tmux sessions are ephemeral.
- **Acceptance:**
  - [ ] TmuxSessionTracker class exists with `activeSessionName` property
  - [ ] `trackSession` stores the session name
  - [ ] `clearTrackedSession` nils the stored name
  - [ ] No persistence to disk — purely in-memory

### S2: Integrate session tracking with Phase 11 attach/detach flows
- **Complexity:** small
- **Deliverable:** Tracker is called on attach (save) and voluntary detach (clear)
- **Files:** `Beacon/Features/Tmux/TmuxService.swift`, `Beacon/Features/Tmux/TmuxSessionTracker.swift`
- **Depends on:** S1
- **Details:** Hook TmuxSessionTracker into the existing TmuxService attach and detach flows from Phase 11. When attach succeeds, call `trackSession(name)`. When the user voluntarily detaches, call `clearTrackedSession()`. When connection is lost (involuntary disconnect), do NOT clear the tracked session — the name is preserved for reattach.
- **Acceptance:**
  - [ ] Successful attach calls `trackSession` with the session name
  - [ ] Voluntary detach calls `clearTrackedSession`
  - [ ] Involuntary disconnect preserves the tracked session name

### S3: Add session existence check after reconnect
- **Complexity:** medium
- **Deliverable:** Post-reconnect logic that checks if the tracked tmux session still exists
- **Files:** `Beacon/Features/Tmux/TmuxSessionTracker.swift`, `Beacon/Features/Tmux/TmuxService.swift`
- **Depends on:** S2
- **Details:** After Phase 10 reconnect completes, check if `trackedSessionName` is non-nil. If a session name is tracked, execute `tmux has-session -t [name]` via TmuxService over the new SSH channel. Parse the exit code: 0 means session exists, non-zero means gone. This check is a single-shot attempt — no retry loop.
- **Acceptance:**
  - [ ] Reconnect completion triggers tracked session check
  - [ ] `tmux has-session -t [name]` is executed via SSH channel
  - [ ] Exit code 0 is interpreted as session-exists
  - [ ] Non-zero exit code is interpreted as session-gone

### S4: Implement auto-reattach when session exists
- **Complexity:** medium
- **Deliverable:** Automatic `tmux attach-session` execution after successful existence check
- **Files:** `Beacon/Features/Tmux/TmuxSessionTracker.swift`, `Beacon/Features/Tmux/TmuxService.swift`
- **Depends on:** S3
- **Details:** When `has-session` confirms the session exists, execute `tmux attach-session -t [name]` via the SSH channel. This sends the command to the terminal's PTY so tmux output renders in the libghostty surface. tmux redraws the terminal content, replacing the Phase 10 display snapshot. If attach fails (race condition, server issue), treat it as the session-gone path.
- **Acceptance:**
  - [ ] `tmux attach-session -t [name]` is sent to PTY after successful has-session
  - [ ] Terminal renders tmux output after reattach
  - [ ] Attach failure falls through to session-gone handling

### S5: Handle session-gone case with clear messaging
- **Complexity:** small
- **Deliverable:** User-facing message when tracked session no longer exists, plus state cleanup
- **Files:** `Beacon/Features/Tmux/TmuxSessionTracker.swift`
- **Depends on:** S3
- **Details:** When `has-session` returns non-zero or attach fails, clear the tracked session name and show a message: "Your tmux session '[name]' is no longer available." The terminal remains on the base shell, ready for use. The user can manually open the tmux session sheet to manage sessions.
- **Acceptance:**
  - [ ] Tracked session name is cleared on session-gone
  - [ ] "Your tmux session '[name]' is no longer available." message is displayed
  - [ ] Terminal remains on base shell and is usable
  - [ ] User can open tmux session sheet manually

### S6: Add transient toast banners for reattach outcomes
- **Complexity:** small
- **Deliverable:** Toast banners for successful reattach and session-gone scenarios
- **Files:** `Beacon/Features/Tmux/TmuxSessionTracker.swift`, `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S4, S5
- **Details:** On successful reattach, show a transient toast banner: "Reattached to tmux session '[name]'". The banner auto-dismisses after ~3 seconds. The session-gone message from S5 also uses the toast banner pattern. Both banners follow the same visual pattern established in Phase 10 reconnect banners.
- **Acceptance:**
  - [ ] "Reattached to tmux session '[name]'" toast appears on successful reattach
  - [ ] Toast auto-dismisses after ~3 seconds
  - [ ] Session-gone message uses the same toast pattern
  - [ ] Banner style matches Phase 10 reconnect banners

### S7: Add VoiceOver announcements for reattach events
- **Complexity:** small
- **Deliverable:** VoiceOver announcements for reattach success and session-gone messages
- **Files:** `Beacon/Features/Tmux/TmuxSessionTracker.swift`
- **Depends on:** S6
- **Details:** Post VoiceOver announcements via `UIAccessibility.post(notification: .announcement, argument:)` for both the reattach success banner and the session-gone message. Announcements fire alongside the visual toast banners.
- **Acceptance:**
  - [ ] Reattach success triggers VoiceOver announcement
  - [ ] Session-gone triggers VoiceOver announcement
  - [ ] Announcements use `UIAccessibility.post`

### S8: Write unit and integration tests
- **Complexity:** medium
- **Deliverable:** Unit tests for tracker state machine and integration tests for reattach flow
- **Files:** `BeaconTests/Features/Tmux/TmuxSessionTrackerTests.swift`
- **Depends on:** S7
- **Details:** Unit tests: verify trackSession stores name, clearTrackedSession nils it, involuntary disconnect preserves it. Test the reattach state machine transitions (tracked → check → attach success, tracked → check → session gone, tracked → check → attach failure → session gone). Integration tests against Docker harness: verify background → reconnect → reattach happy path, and background → reconnect → session-gone scenario.
- **Acceptance:**
  - [ ] Unit tests cover track, clear, and preserve-on-disconnect
  - [ ] Unit tests cover all state machine transitions
  - [ ] Integration test passes for reattach happy path against Docker harness
  - [ ] Integration test passes for session-gone scenario against Docker harness

### S9: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** All UAT checklist items verified and passing
- **Files:** none (manual verification)
- **Depends on:** S8
- **Details:** Walk through every item in the UAT checklist (UAT-1 through UAT-12) against the Docker harness. Document any failures and fix before marking phase complete.
- **Acceptance:**
  - [ ] All 12 UAT checklist items pass
  - [ ] Any failures found are fixed and re-verified

## 12. References
- [ios-lifecycle-strategy.md](../refs/ios-lifecycle-strategy.md) — Section 6.2: Foreground Return
