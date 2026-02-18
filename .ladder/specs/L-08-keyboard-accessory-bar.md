# Phase 8: Keyboard Accessory Bar

## 1. Objective
Add an accessory key bar above the iOS keyboard to provide special keys essential for terminal usage (arrows, Ctrl, Tab, Esc), making terminal work practical on mobile.

## 2. Entry Criteria
1. Phase 7 accepted.
2. Terminal surface handles keyboard input and rotation.

## 3. Scope In
1. Accessory bar with keys: Up, Down, Left, Right, Ctrl, Tab, Shift+Tab, Esc.
2. One-shot modifier behavior (Ctrl tapped then next key sends Ctrl+key, then modifier resets).
3. Integration with libghostty input pipeline via `ghostty_surface_key()`.
4. Labels understandable to non-terminal-experts.

## 4. Scope Out
1. Custom key remapping or configurable accessory bar.
2. External keyboard shortcut configuration.
3. Full modifier key support (Alt/Option — deferred).

## 5. Product Requirements
- **PR-1:** Accessory bar is displayed above the iOS software keyboard when terminal is active.
- **PR-2:** Keys provided (left to right): Esc, Ctrl, Tab, Up, Down, Left, Right.
- **PR-3:** Shift+Tab is accessible via long-press on Tab (or a secondary Shift key — implementation choice).
- **PR-4:** Each key tap emits the corresponding terminal control sequence via `ghostty_surface_key()`.
- **PR-5:** Key labels: "Esc", "Ctrl", "Tab", "↑", "↓", "←", "→".
- **PR-6:** Ctrl is a one-shot modifier: tap Ctrl → Ctrl is visually activated (highlighted) → tap next character key → Ctrl+key sequence is sent → Ctrl deactivates immediately.
- **PR-7:** No sticky modifier behavior — Ctrl never stays active across multiple keystrokes.
- **PR-8:** Tapping Ctrl twice deactivates it (toggle off without sending anything).
- **PR-9:** If Ctrl is active and user taps an accessory key (e.g., arrow), Ctrl+arrow is sent and Ctrl deactivates.
- **PR-10:** Accessory bar appears when the software keyboard is visible.
- **PR-11:** Accessory bar hides when the keyboard is dismissed.
- **PR-12:** Accessory bar does not appear with external keyboards (external keyboards have their own modifier keys).
- **PR-13:** Key tap to terminal response: <50ms (imperceptible).
- **PR-14:** Accessory bar renders without lag when keyboard appears.

## 6. UX Requirements
- **UX-1:** Keys are large enough for comfortable tapping (minimum 44pt tap target).
- **UX-2:** Key labels are readable and not abbreviated beyond recognition.
- **UX-3:** Ctrl active state is visually obvious (color change, highlight).
- **UX-4:** Tapping a key provides haptic feedback (light impact).
- **UX-5:** Accessory bar does not obscure terminal content — terminal resizes to accommodate.

## 7. Accessibility Requirements
- **A11Y-1:** All accessory keys have VoiceOver labels: "Escape", "Control modifier", "Tab", "Up arrow", "Down arrow", "Left arrow", "Right arrow".
- **A11Y-2:** Ctrl active state is announced by VoiceOver: "Control modifier active".
- **A11Y-3:** VoiceOver users can navigate the accessory bar.
- **A11Y-4:** Accessory keys have minimum 44pt × 44pt tap target for accessibility.

## 8. UAT Checklist
- [ ] UAT-1: Connect and open terminal — confirm accessory bar appears above keyboard.
- [ ] UAT-2: Tap Up/Down — confirm shell history navigation works.
- [ ] UAT-3: Tap Left/Right — confirm cursor movement within command line.
- [ ] UAT-4: Tap Tab — confirm shell tab-completion works (e.g., type partial command, tap Tab).
- [ ] UAT-5: Tap Ctrl then `c` — confirm Ctrl+C sends interrupt (stops a running command like `sleep 100`).
- [ ] UAT-6: Tap Ctrl then `d` — confirm Ctrl+D sends EOF (in an appropriate context).
- [ ] UAT-7: Tap Esc — confirm escape sends (useful in editors like vim/nano).
- [ ] UAT-8: Double-tap Ctrl — confirm it toggles off without sending anything.
- [ ] UAT-9: Tap Ctrl then an arrow key — confirm combo is sent and Ctrl deactivates.
- [ ] UAT-10: Dismiss keyboard — confirm accessory bar hides.

## 9. Test Allocation

| Type | Scope | Method |
|------|-------|--------|
| Unit | Key mapping logic — each accessory key maps to correct terminal sequence | XCTest |
| Unit | Modifier state machine — activate, send combo, deactivate, toggle off | XCTest |
| Unit | Sequence generation — correct bytes for Ctrl+key combos | XCTest |
| Critical | Accessory key → libghostty → SSH channel path (character key) | XCTest integration |
| Critical | Accessory key → libghostty → SSH channel path (modifier combo) | XCTest integration |
| Full | UI-driven accessory key test (optional) | XCUITest |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. All accessory keys produce correct terminal sequences.
3. Ctrl modifier is strictly one-shot — no sticky behavior.
4. Accessory bar does not interfere with normal typing.
5. Known gaps documented before Phase 9.

## 11. Step Sequence

### S1: Create accessory bar view with key buttons
- **Complexity:** medium
- **Deliverable:** A SwiftUI or UIKit accessory bar view containing all seven key buttons with correct labels.
- **Files:** `Beacon/Features/Terminal/AccessoryBar/TerminalAccessoryBar.swift`
- **Depends on:** none
- **Details:** Build a horizontal bar view with buttons for Esc, Ctrl, Tab, ↑, ↓, ←, →. Each button must meet the 44pt minimum tap target (UX-1). Apply key labels per PR-5. Include haptic feedback on tap (UX-4).
- **Acceptance:**
  - [ ] Bar renders with all seven keys in correct order (PR-2).
  - [ ] Each button meets 44pt tap target minimum.
  - [ ] Haptic feedback fires on key tap.

### S2: Attach accessory bar as inputAccessoryView
- **Complexity:** small
- **Deliverable:** Accessory bar attached to the terminal's text input responder so it appears above the keyboard.
- **Files:** `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S1
- **Details:** Set the accessory bar as the `inputAccessoryView` on the terminal's UIKit text input responder. The bar must appear when the software keyboard is shown and hide when dismissed (PR-10, PR-11). Must not appear with external keyboards (PR-12).
- **Acceptance:**
  - [ ] Accessory bar appears above software keyboard when terminal is active.
  - [ ] Accessory bar hides when keyboard is dismissed.
  - [ ] Accessory bar does not appear with external keyboard connected.

### S3: Map each key to its terminal sequence
- **Complexity:** medium
- **Deliverable:** Key-to-sequence mapping that translates each accessory key into the correct terminal input.
- **Files:** `Beacon/Features/Terminal/AccessoryBar/AccessoryKeyMapper.swift`
- **Depends on:** S1
- **Details:** Create a mapping from each accessory key to its terminal representation suitable for `ghostty_surface_key()`. Arrow keys map to cursor movement sequences, Tab to HT, Esc to ESC, Ctrl is handled by the modifier state machine (S4). Include Shift+Tab via long-press on Tab (PR-3).
- **Acceptance:**
  - [ ] Each non-modifier key maps to the correct terminal sequence.
  - [ ] Shift+Tab is accessible via long-press on Tab.
  - [ ] Mapping is covered by unit tests.

### S4: Implement Ctrl one-shot modifier state machine
- **Complexity:** medium
- **Deliverable:** A state machine managing Ctrl modifier activation, combo dispatch, and deactivation.
- **Files:** `Beacon/Features/Terminal/AccessoryBar/ModifierStateMachine.swift`
- **Depends on:** S3
- **Details:** Implement a state machine with states: inactive, armed. Tap Ctrl → armed (visually highlighted per UX-3). Next key tap → send Ctrl+key combo → return to inactive (PR-6). Double-tap Ctrl → return to inactive without sending (PR-8). Ctrl+accessory key (e.g., arrow) sends combo and deactivates (PR-9). No sticky behavior (PR-7).
- **Acceptance:**
  - [ ] Ctrl tap arms the modifier with visual highlight.
  - [ ] Next key sends Ctrl+key and deactivates modifier.
  - [ ] Double-tap Ctrl toggles off without sending.
  - [ ] Ctrl + arrow key sends combo and deactivates.
  - [ ] State machine has unit tests for all transitions.

### S5: Integrate with ghostty_surface_key() for all key events
- **Complexity:** medium
- **Deliverable:** All accessory key taps dispatch through `ghostty_surface_key()` into the libghostty input pipeline.
- **Files:** `Beacon/Features/Terminal/AccessoryBar/AccessoryKeyMapper.swift`, `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S3, S4
- **Details:** Wire the key mapper and modifier state machine output into `ghostty_surface_key()` so each tap produces the correct terminal input. Ensure response latency is under 50ms (PR-13) and the bar renders without lag when the keyboard appears (PR-14).
- **Acceptance:**
  - [ ] All accessory keys produce correct input via `ghostty_surface_key()`.
  - [ ] Modifier combos route through the state machine before dispatch.
  - [ ] Key tap to terminal response is imperceptible (<50ms).

### S6: Add VoiceOver labels to all keys
- **Complexity:** small
- **Deliverable:** VoiceOver accessibility labels and announcements for all accessory keys.
- **Files:** `Beacon/Features/Terminal/AccessoryBar/TerminalAccessoryBar.swift`
- **Depends on:** S1
- **Details:** Set VoiceOver labels per A11Y-1: "Escape", "Control modifier", "Tab", "Up arrow", "Down arrow", "Left arrow", "Right arrow". Announce Ctrl active state as "Control modifier active" (A11Y-2). Ensure VoiceOver navigation works across the bar (A11Y-3). Maintain 44pt × 44pt tap targets (A11Y-4).
- **Acceptance:**
  - [ ] Each key has correct VoiceOver label.
  - [ ] Ctrl armed state announces "Control modifier active".
  - [ ] VoiceOver can navigate all keys in the bar.

### S7: Handle accessory bar visibility (keyboard show/hide)
- **Complexity:** small
- **Deliverable:** Accessory bar visibility correctly tracks keyboard state and terminal resizes to accommodate.
- **Files:** `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S2
- **Details:** Ensure the terminal content area resizes when the accessory bar appears so it is not obscured (UX-5). Coordinate with keyboard show/hide notifications. Verify the bar does not appear when an external keyboard is connected (PR-12).
- **Acceptance:**
  - [ ] Terminal content resizes when accessory bar appears.
  - [ ] No terminal content is obscured by the accessory bar.
  - [ ] External keyboard does not trigger accessory bar.

### S8: Test all keys against Docker harness shell
- **Complexity:** medium
- **Deliverable:** Integration tests validating accessory keys through the full SSH → terminal pipeline.
- **Files:** `BeaconTests/Integration/AccessoryBarIntegrationTests.swift`
- **Depends on:** S5
- **Details:** Write critical-lane integration tests connecting to the Docker test harness. Test a character key (e.g., arrow for history navigation) and a modifier combo (e.g., Ctrl+C to interrupt). Verify output reaches the terminal correctly.
- **Acceptance:**
  - [ ] Character key integration test passes against Docker harness.
  - [ ] Modifier combo integration test passes against Docker harness.

### S9: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** All UAT items verified and checked off.
- **Files:** `.ladder/specs/L-08-keyboard-accessory-bar.md`
- **Depends on:** S1, S2, S3, S4, S5, S6, S7, S8
- **Details:** Walk through UAT-1 through UAT-10 on a device or simulator. Mark each item as passing. Document any known gaps for Phase 9.
- **Acceptance:**
  - [ ] All 10 UAT checklist items pass.
  - [ ] Known gaps (if any) documented.

## 12. References
- [terminal-engine-decision.md](../refs/terminal-engine-decision.md) — input via `ghostty_surface_key()`
