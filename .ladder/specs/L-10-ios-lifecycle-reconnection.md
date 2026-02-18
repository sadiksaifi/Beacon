# Phase 10: iOS Lifecycle & Reconnection

## 1. Objective
Handle iOS app backgrounding and foregrounding gracefully: disconnect cleanly on background, preserve terminal display, reconnect automatically on foreground return.

## 2. Entry Criteria
1. Phase 9 accepted.
2. Terminal surface with full interactivity (keyboard, accessory, copy/paste) is functional.

## 3. Scope In
1. Detect app backgrounding (`sceneWillResignActive`).
2. Use `beginBackgroundTask` for graceful SSH disconnect.
3. Save terminal display state before suspension.
4. Detect connection loss on foreground return.
5. Restore terminal display immediately from saved state.
6. Auto-reconnect with inline status banner (not blocking alert).
7. Manual reconnect fallback button.
8. Preserve connection identity across reconnect.
9. Network availability monitoring via NWPathMonitor.

## 4. Scope Out
1. Background connection persistence (not possible on iOS — see ref doc).
2. tmux reattach on reconnect (Phase 12).
3. Multi-connection management.

## 5. Product Requirements
- **PR-1:** On `sceneWillResignActive`, begin background cleanup.
- **PR-2:** Call `beginBackgroundTask` to get OS-granted cleanup window.
- **PR-3:** Save terminal display snapshot (current scrollback content as text buffer or rendered image).
- **PR-4:** Save connection identity (host, port, username, auth method, key ID if applicable) for reconnect.
- **PR-5:** Send graceful SSH disconnect to server.
- **PR-6:** Transition connection state to "Disconnected (app suspended)".
- **PR-7:** Call `endBackgroundTask` before OS deadline.
- **PR-8:** On `sceneWillEnterForeground`, restore terminal display from saved snapshot immediately.
- **PR-9:** User sees their last terminal state (not a blank screen) within the first rendered frame.
- **PR-10:** Check network availability via `NWPathMonitor` on foreground return.
- **PR-11:** If network is available, begin auto-reconnect.
- **PR-12:** Show inline status banner at top of terminal: "Reconnecting…"
- **PR-13:** On reconnect success: banner shows "Reconnected" briefly, then dismisses. Terminal resumes live rendering.
- **PR-14:** On reconnect failure: banner shows "Connection lost — Tap to reconnect." User can tap to retry.
- **PR-15:** If network is unavailable: banner shows "No network — waiting for connection." Auto-reconnect begins when network returns.
- **PR-16:** Reconnect uses the same connection parameters as the original connection.
- **PR-17:** If password is stored in Keychain, reconnect uses it automatically (biometric prompt may appear).
- **PR-18:** If key auth was used, reconnect uses the same key (biometric prompt for Keychain access).
- **PR-19:** User does not need to re-enter credentials for auto-reconnect.
- **PR-20:** Use `NWPathMonitor` to observe network status.
- **PR-21:** Detect transitions: WiFi → cellular, cellular → WiFi, connected → disconnected, disconnected → connected.
- **PR-22:** On network loss while foregrounded: if SSH connection drops, show inline banner.
- **PR-23:** On network restoration: attempt reconnect automatically.
- **PR-24:** If auto-reconnect fails, user can tap the banner or a reconnect button.
- **PR-25:** Manual reconnect follows the same flow as auto-reconnect.
- **PR-26:** User can also navigate back to connection list and connect again manually.

## 6. UX Requirements
- **UX-1:** Terminal is never blank on foreground return — snapshot is shown immediately.
- **UX-2:** Reconnect status is shown as an inline banner, not a blocking modal/alert.
- **UX-3:** Banner is dismissible and not intrusive.
- **UX-4:** Reconnect happens without requiring user interaction (unless credentials need biometric verification).
- **UX-5:** If reconnect takes more than a few seconds, status is visible (not a silent wait).

## 7. Accessibility Requirements
- **A11Y-1:** Reconnect banner is announced by VoiceOver when it appears.
- **A11Y-2:** Banner "Tap to reconnect" action is VoiceOver-accessible.
- **A11Y-3:** Terminal snapshot view maintains VoiceOver label: "Terminal — reconnecting to [host]".
- **A11Y-4:** Network status changes are announced by VoiceOver.

## 8. UAT Checklist
- [ ] UAT-1: Connect to Docker harness and run a few commands.
- [ ] UAT-2: Background the app (press Home or switch to another app).
- [ ] UAT-3: Wait 10 seconds.
- [ ] UAT-4: Return to Beacon — confirm terminal shows previous content (not blank).
- [ ] UAT-5: Confirm "Reconnecting…" banner appears.
- [ ] UAT-6: Confirm connection re-establishes and banner dismisses.
- [ ] UAT-7: Type a command after reconnect — confirm terminal is live.
- [ ] UAT-8: Connect, then disable WiFi/network on the device.
- [ ] UAT-9: Confirm "Connection lost" banner appears.
- [ ] UAT-10: Re-enable network — confirm auto-reconnect attempt.
- [ ] UAT-11: Connect, background the app, wait 30+ seconds.
- [ ] UAT-12: Return — confirm reconnect flow works even after longer suspension.
- [ ] UAT-13: Connect, background, stop the Docker harness, return — confirm clear "Connection lost" message with retry option.

## 9. Test Allocation

| Type | Scope | Method |
|------|-------|--------|
| Unit | Background cleanup sequence — save snapshot, save identity, disconnect | XCTest |
| Unit | Snapshot save/restore — terminal buffer serialization and deserialization | XCTest |
| Unit | Reconnect state machine — state transitions, retry logic | XCTest |
| Unit | NWPathMonitor handling — network status change callbacks | XCTest |
| Unit | Banner state logic — banner text and visibility for each reconnect state | XCTest |
| Critical | Background → foreground → reconnect flow against Docker harness | XCTest integration |
| Full | Network change scenarios (optional) | XCTest integration |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. Terminal is never blank on foreground return.
3. Auto-reconnect works for standard background/foreground cycle.
4. Network loss is detected and handled with clear messaging.
5. Manual reconnect fallback works.
6. Known gaps documented before Phase 11.

## 11. Step Sequence

### S1: Add scene lifecycle observers
- **Complexity:** small
- **Deliverable:** Scene lifecycle hooks that detect backgrounding and foregrounding.
- **Files:** `Beacon/Features/Lifecycle/SceneLifecycleObserver.swift`
- **Depends on:** none
- **Details:** Register for `sceneWillResignActive` and `sceneWillEnterForeground` notifications (or use `ScenePhase` in SwiftUI). When app backgrounds, trigger background cleanup. When app foregrounds, trigger restore and reconnect flow. Publish lifecycle events via a protocol or Combine publisher for other components to observe.
- **Acceptance:**
  - [ ] `sceneWillResignActive` triggers background cleanup entry point (PR-1).
  - [ ] `sceneWillEnterForeground` triggers foreground restore entry point (PR-8).
  - [ ] Other components can subscribe to lifecycle events.

### S2: Implement beginBackgroundTask cleanup sequence
- **Complexity:** medium
- **Deliverable:** Background task that gracefully disconnects SSH, saves connection identity, and completes before OS deadline.
- **Files:** `Beacon/Features/Lifecycle/BackgroundCleanupTask.swift`
- **Depends on:** S1
- **Details:** On background entry, call `beginBackgroundTask` (PR-2). Save connection identity — host, port, username, auth method, key ID — for later reconnect (PR-4). Send graceful SSH disconnect (PR-5). Transition connection state to "Disconnected (app suspended)" (PR-6). Call `endBackgroundTask` before OS deadline (PR-7). Coordinate with S3 for snapshot save.
- **Acceptance:**
  - [ ] `beginBackgroundTask` is called on background entry (PR-2).
  - [ ] Connection identity is saved for reconnect (PR-4).
  - [ ] Graceful SSH disconnect is sent (PR-5).
  - [ ] Connection state transitions to "Disconnected (app suspended)" (PR-6).
  - [ ] `endBackgroundTask` is called before deadline (PR-7).

### S3: Implement terminal snapshot save
- **Complexity:** medium
- **Deliverable:** Terminal display snapshot captured and persisted before suspension.
- **Files:** `Beacon/Features/Terminal/Snapshot/TerminalSnapshotManager.swift`
- **Depends on:** S1
- **Details:** On background entry (from S1 lifecycle event), capture the current terminal display state — the visible scrollback content as a text buffer or rendered image (PR-3). Store the snapshot in memory or to a temporary file so it can be restored on foreground return. The snapshot must include enough content to render the terminal view identically on restore.
- **Acceptance:**
  - [ ] Terminal display snapshot is saved on background entry (PR-3).
  - [ ] Snapshot captures current scrollback content.
  - [ ] Snapshot is retrievable for restore on foreground return.

### S4: Implement terminal snapshot restore on foreground
- **Complexity:** medium
- **Deliverable:** Terminal view restores from saved snapshot immediately on foreground return.
- **Files:** `Beacon/Features/Terminal/Snapshot/TerminalSnapshotManager.swift`, `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S3
- **Details:** On foreground return (from S1 lifecycle event), restore the terminal display from the saved snapshot immediately (PR-8). The user must see their last terminal state — not a blank screen — within the first rendered frame (PR-9, UX-1). If no snapshot exists, show the terminal view with an appropriate placeholder.
- **Acceptance:**
  - [ ] Terminal display is restored from snapshot on foreground (PR-8).
  - [ ] User sees previous terminal content within the first rendered frame (PR-9, UX-1).
  - [ ] No blank screen on foreground return.

### S5: Implement reconnect state machine
- **Complexity:** medium
- **Deliverable:** State machine managing reconnect lifecycle: idle → reconnecting → connected / failed / waitingForNetwork.
- **Files:** `Beacon/Features/Connection/ReconnectStateMachine.swift`
- **Depends on:** S2
- **Details:** Build a state machine that drives the reconnect flow. States: idle, reconnecting, connected, failed, waitingForNetwork. On foreground return, check network availability (PR-10). If network is available, transition to reconnecting and use saved connection identity to reconnect (PR-11, PR-16). Use stored Keychain credentials — password or key — for automatic auth (PR-17, PR-18, PR-19). On success, transition to connected. On failure, transition to failed. Expose state changes via Combine publisher.
- **Acceptance:**
  - [ ] State machine transitions: idle → reconnecting → connected on success (PR-11).
  - [ ] State machine transitions: idle → reconnecting → failed on failure.
  - [ ] Reconnect uses saved connection parameters (PR-16).
  - [ ] Keychain credentials are used for auto-reconnect (PR-17, PR-18, PR-19).
  - [ ] State changes are observable by UI components.

### S6: Implement reconnect banner UI with manual retry
- **Complexity:** medium
- **Deliverable:** Inline banner at top of terminal showing reconnect status with tap-to-retry support.
- **Files:** `Beacon/Features/Connection/ReconnectBannerView.swift`, `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S5
- **Details:** Add an inline banner at the top of the terminal view (UX-2). Banner shows: "Reconnecting…" during reconnect attempt (PR-12), "Reconnected" briefly on success (PR-13), "Connection lost — Tap to reconnect." on failure (PR-14), "No network — waiting for connection." when network unavailable (PR-15). Banner is dismissible (UX-3). Tapping the banner triggers manual reconnect using the same state machine (PR-24, PR-25). Reconnect status is always visible if taking more than a few seconds (UX-5).
- **Acceptance:**
  - [ ] Banner shows "Reconnecting…" during reconnect (PR-12).
  - [ ] Banner shows "Reconnected" briefly on success, then dismisses (PR-13).
  - [ ] Banner shows "Connection lost — Tap to reconnect." on failure (PR-14).
  - [ ] Banner shows "No network — waiting for connection." when no network (PR-15).
  - [ ] Banner is inline, not a blocking modal (UX-2).
  - [ ] Banner is dismissible (UX-3).
  - [ ] Tapping banner triggers manual reconnect (PR-24, PR-25).

### S7: Wire reconnect success and failure states
- **Complexity:** medium
- **Deliverable:** Full integration of reconnect state machine with terminal session, banner, and connection lifecycle.
- **Files:** `Beacon/Features/Connection/ReconnectStateMachine.swift`, `Beacon/Features/Connection/ReconnectBannerView.swift`, `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S5, S6
- **Details:** Wire the reconnect state machine outputs to concrete actions. On success: dismiss banner, resume live terminal rendering, terminal accepts input (PR-13). On failure: keep banner visible with retry option (PR-14). On reconnect, re-establish the SSH channel and resume terminal data flow. User can also navigate back to connection list for manual connect (PR-26). Ensure reconnect happens without requiring user interaction unless biometric verification is needed (UX-4).
- **Acceptance:**
  - [ ] On reconnect success, terminal resumes live rendering (PR-13).
  - [ ] On reconnect failure, banner shows retry option (PR-14).
  - [ ] SSH channel is re-established and terminal data flows on reconnect.
  - [ ] User can navigate to connection list as fallback (PR-26).
  - [ ] No user interaction required for auto-reconnect (UX-4).

### S8: Implement NWPathMonitor network monitoring
- **Complexity:** medium
- **Deliverable:** Network monitor that detects connectivity changes and triggers reconnect or shows status.
- **Files:** `Beacon/Features/Network/NetworkMonitor.swift`
- **Depends on:** S5
- **Details:** Use `NWPathMonitor` to observe network status (PR-20). Detect transitions: WiFi → cellular, cellular → WiFi, connected → disconnected, disconnected → connected (PR-21). On network loss while foregrounded, if SSH connection drops, trigger the reconnect state machine to show banner (PR-22). On network restoration, trigger auto-reconnect attempt (PR-23). Feed network state into the reconnect state machine's waitingForNetwork state.
- **Acceptance:**
  - [ ] NWPathMonitor observes network status (PR-20).
  - [ ] Network transitions are detected (PR-21).
  - [ ] Network loss triggers reconnect banner if connection drops (PR-22).
  - [ ] Network restoration triggers auto-reconnect (PR-23).

### S9: Add VoiceOver labels for banner and states
- **Complexity:** small
- **Deliverable:** VoiceOver accessibility for reconnect banner and network status.
- **Files:** `Beacon/Features/Connection/ReconnectBannerView.swift`, `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S6
- **Details:** Ensure reconnect banner is announced by VoiceOver when it appears (A11Y-1). Make "Tap to reconnect" action accessible via VoiceOver (A11Y-2). Add VoiceOver label to terminal snapshot view: "Terminal — reconnecting to [host]" (A11Y-3). Announce network status changes via VoiceOver (A11Y-4).
- **Acceptance:**
  - [ ] Banner is announced by VoiceOver on appearance (A11Y-1).
  - [ ] "Tap to reconnect" is VoiceOver-accessible (A11Y-2).
  - [ ] Terminal snapshot view has VoiceOver label (A11Y-3).
  - [ ] Network status changes announced by VoiceOver (A11Y-4).

### S10: Test background/foreground cycles
- **Complexity:** medium
- **Deliverable:** Unit and integration tests covering lifecycle, snapshot, reconnect, and network handling.
- **Files:** `BeaconTests/Unit/BackgroundCleanupTests.swift`, `BeaconTests/Unit/TerminalSnapshotTests.swift`, `BeaconTests/Unit/ReconnectStateMachineTests.swift`, `BeaconTests/Unit/NetworkMonitorTests.swift`, `BeaconTests/Integration/LifecycleReconnectIntegrationTests.swift`
- **Depends on:** S7, S8
- **Details:** Write unit tests for: background cleanup sequence, snapshot save/restore, reconnect state machine transitions, NWPathMonitor handling, and banner state logic. Write critical-lane integration test for the full background → foreground → reconnect flow against Docker harness. Optionally test network change scenarios.
- **Acceptance:**
  - [ ] Unit tests for background cleanup sequence pass.
  - [ ] Unit tests for snapshot save/restore pass.
  - [ ] Unit tests for reconnect state machine pass.
  - [ ] Unit tests for network monitor pass.
  - [ ] Integration test for background → foreground → reconnect passes against Docker harness.

### S11: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** All UAT items verified and checked off.
- **Files:** `.ladder/specs/L-10-ios-lifecycle-reconnection.md`
- **Depends on:** S1, S2, S3, S4, S5, S6, S7, S8, S9, S10
- **Details:** Walk through UAT-1 through UAT-13 on a device or simulator. Mark each item as passing. Document any known gaps for Phase 11.
- **Acceptance:**
  - [ ] All 13 UAT checklist items pass.
  - [ ] Known gaps (if any) documented.

## 12. References
- [ios-lifecycle-strategy.md](../refs/ios-lifecycle-strategy.md)
