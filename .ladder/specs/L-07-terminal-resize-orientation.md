# Phase 7: Terminal Resize & Orientation

## 1. Objective
Handle device rotation and dynamic layout changes so the terminal adapts correctly to portrait and landscape orientations.

## 2. Entry Criteria
1. Phase 6 accepted.
2. Terminal surface renders and accepts input.

## 3. Scope In
1. Device rotation handling (portrait ↔ landscape).
2. Terminal dimension recalculation via `ghostty_surface_set_size()`.
3. SSH channel window-change notification (PTY resize).
4. Safe area inset handling across orientations.
5. Keyboard appearance/disappearance animation coordination during rotation.

## 4. Scope Out
1. Split-screen or multitasking (iPad-only features).
2. External display support.
3. Custom terminal font sizing (Phase 14).

## 5. Product Requirements
1. **PR-1:** Terminal view handles rotation from portrait to landscape and back.
2. **PR-2:** Terminal content is preserved during rotation (no content loss).
3. **PR-3:** Rotation animation is smooth — no flicker or rendering artifacts.
4. **PR-4:** Terminal dimensions (columns × rows) are recalculated after rotation.
5. **PR-5:** On view layout change, compute new terminal dimensions from view bounds (excluding safe area insets), current cell size (from libghostty font metrics), and keyboard height (if visible).
6. **PR-6:** Call `ghostty_surface_set_size()` with new pixel dimensions.
7. **PR-7:** Send SSH channel window-change notification with new columns × rows to remote server.
8. **PR-8:** Remote shell reflows content to new dimensions.
9. **PR-9:** Terminal content does not render behind the notch, Dynamic Island, or home indicator.
10. **PR-10:** Safe area insets are applied correctly in both orientations.
11. **PR-11:** Keyboard height is accounted for in available terminal area.
12. **PR-12:** When keyboard is visible during rotation, terminal area is recalculated accounting for the new keyboard frame.
13. **PR-13:** No gap or overlap between terminal and keyboard during/after rotation.
14. **PR-14:** Keyboard animation and terminal resize are coordinated (no visual jump).

## 6. UX Requirements
1. **UX-1:** Rotation feels natural and instant — no lag or blank frames.
2. **UX-2:** Terminal content is readable immediately after rotation.
3. **UX-3:** User's cursor position and command line are not lost during rotation.

## 7. Accessibility Requirements
1. **A11Y-1:** VoiceOver announces orientation change if VoiceOver is active.
2. **A11Y-2:** Terminal remains accessible after rotation.
3. **A11Y-3:** Dynamic Type text outside the terminal reflows correctly.

## 8. UAT Checklist
- [ ] UAT-1: Connect to host in portrait mode — confirm terminal renders.
- [ ] UAT-2: Rotate to landscape — confirm terminal fills new layout without clipping.
- [ ] UAT-3: Type a command in landscape — confirm input works.
- [ ] UAT-4: Rotate back to portrait — confirm terminal readjusts.
- [ ] UAT-5: Run `tput cols; tput lines` before and after rotation — confirm dimensions change.
- [ ] UAT-6: Open keyboard, then rotate — confirm no gap or overlap.
- [ ] UAT-7: Rotate with keyboard visible, then dismiss keyboard — confirm terminal expands.

## 9. Test Allocation
| Type | Scope | Method |
|------|-------|--------|
| Unit | Dimension calculation (cols × rows from bounds, cell size, keyboard, safe area) | XCTest |
| Unit | Safe area inset application logic | XCTest |
| Unit | SSH window-change notification payload | XCTest |
| Full | Automated rotation with dimension verification (optional) | XCUITest |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. Terminal adapts to both orientations without content loss.
3. SSH channel receives correct window-change notifications.
4. No rendering artifacts during or after rotation.
5. Known gaps documented before Phase 8.

## 11. Step Sequence

### S1: Add layout change observer to terminal view
- **Complexity:** small
- **Deliverable:** Terminal view detects bounds changes from rotation and keyboard events
- **Files:** `Beacon/Terminal/TerminalView.swift`
- **Depends on:** none
- **Details:** Hook into the UIKit hosting view's layout cycle to detect when the terminal view's bounds change. Trigger dimension recalculation on every layout pass where bounds differ from the previous value. Debounce to avoid redundant recalculations on unchanged bounds.
- **Acceptance:**
  - [ ] Layout change callback fires on device rotation
  - [ ] Callback fires on keyboard show/hide
  - [ ] No redundant callback when bounds are unchanged

### S2: Implement terminal dimension recalculation
- **Complexity:** medium
- **Deliverable:** Pure function computing cols × rows from view bounds, cell size, safe area, and keyboard height
- **Files:** `Beacon/Terminal/TerminalSizeCalculator.swift`
- **Depends on:** S1
- **Details:** Given view bounds, subtract safe area insets and keyboard height to get available pixel area. Divide by cell size (from libghostty font metrics) to get columns and rows. Return a struct with both pixel dimensions and grid dimensions.
- **Acceptance:**
  - [ ] Correct cols × rows for portrait dimensions
  - [ ] Correct cols × rows for landscape dimensions
  - [ ] Keyboard height reduces available rows
  - [ ] Safe area insets reduce available area

### S3: Call `ghostty_surface_set_size()` on layout change
- **Complexity:** small
- **Deliverable:** Terminal surface resizes to match recalculated dimensions
- **Files:** `Beacon/Terminal/TerminalView.swift`
- **Depends on:** S2
- **Details:** Wire the dimension recalculation output into `ghostty_surface_set_size()` with the new pixel dimensions. The terminal surface re-renders at the new size without flicker or content loss.
- **Acceptance:**
  - [ ] `ghostty_surface_set_size()` called with correct pixel dimensions after rotation
  - [ ] Terminal re-renders at new size
  - [ ] No content loss during resize

### S4: Send SSH channel window-change notification
- **Complexity:** small
- **Deliverable:** Remote server receives updated terminal dimensions on resize
- **Files:** `Beacon/SSH/SSHSession.swift`
- **Depends on:** S2
- **Details:** After recalculating dimensions, send an SSH channel window-change request with the new columns × rows. This triggers the remote PTY to resize and the shell to reflow content.
- **Acceptance:**
  - [ ] Window-change notification sent with correct cols × rows
  - [ ] `tput cols` and `tput lines` on remote reflect new dimensions

### S5: Handle keyboard frame changes during rotation
- **Complexity:** medium
- **Deliverable:** Terminal area adjusts smoothly when keyboard is visible during rotation
- **Files:** `Beacon/Terminal/TerminalView.swift`, `Beacon/Terminal/KeyboardObserver.swift`
- **Depends on:** S2
- **Details:** Subscribe to keyboard willChangeFrame notifications. During rotation with keyboard visible, feed the updated keyboard height into dimension recalculation. Coordinate the terminal resize animation with the keyboard animation curve and duration so there is no visual jump.
- **Acceptance:**
  - [ ] No gap or overlap between terminal and keyboard after rotation
  - [ ] Terminal resize animation matches keyboard animation timing
  - [ ] Dismissing keyboard after rotation expands terminal correctly

### S6: Apply safe area insets across orientations
- **Complexity:** small
- **Deliverable:** Terminal content respects safe areas in both portrait and landscape
- **Files:** `Beacon/Terminal/TerminalView.swift`
- **Depends on:** S1
- **Details:** Read current safe area insets from the view and pass them into dimension recalculation. In landscape on notched devices, safe area shifts to the sides — ensure content doesn't render behind the notch, Dynamic Island, or home indicator in either orientation.
- **Acceptance:**
  - [ ] No content behind notch/Dynamic Island in portrait
  - [ ] No content behind sensor housing in landscape
  - [ ] Home indicator area respected in both orientations

## 12. References
- [terminal-engine-decision.md](../refs/terminal-engine-decision.md) — resize via `ghostty_surface_set_size()`
