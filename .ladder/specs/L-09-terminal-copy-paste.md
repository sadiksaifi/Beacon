# Phase 9: Terminal Copy & Paste

## 1. Objective
Enable copy and paste in the terminal so users can extract output and insert text from the clipboard.

## 2. Entry Criteria
1. Phase 8 accepted.
2. Terminal surface with keyboard and accessory bar is functional.

## 3. Scope In
1. Touch-based text selection (long-press to start, drag to extend).
2. Copy selected text to iOS clipboard (UIPasteboard).
3. Paste from iOS clipboard into terminal.
4. Context menu or floating toolbar for Copy/Paste actions.
5. Integration with libghostty's selection API.

## 4. Scope Out
1. Selection by word/line (double-tap, triple-tap — future enhancement).
2. Find-in-terminal.
3. Image copy from terminal.

## 5. Product Requirements
- **PR-1:** Long-press on terminal starts selection mode.
- **PR-2:** Selection start point is near the long-press location (snapped to character boundary).
- **PR-3:** Drag extends the selection (continuous, character-by-character).
- **PR-4:** Selection is visually highlighted (distinct background color).
- **PR-5:** Selection handles (start/end drag points) are visible and draggable for adjustment.
- **PR-6:** Tapping outside the selection clears it.
- **PR-7:** After selection, a context menu or floating toolbar appears with "Copy" action.
- **PR-8:** Tapping "Copy" places the selected text on UIPasteboard as plain text.
- **PR-9:** Copy action clears the selection after copying.
- **PR-10:** If nothing is selected, Copy is not available.
- **PR-11:** Paste action is available in the context menu or floating toolbar.
- **PR-12:** Tapping "Paste" reads plain text from UIPasteboard.
- **PR-13:** Pasted text is sent to the terminal input (to the remote shell via SSH channel).
- **PR-14:** Paste works regardless of whether text is selected.
- **PR-15:** If clipboard is empty, Paste is disabled or hidden.
- **PR-16:** Context menu appears near the selection or long-press location.
- **PR-17:** Menu items: "Copy" (if text selected), "Paste" (if clipboard has text), "Select All".
- **PR-18:** "Select All" selects all visible terminal content.
- **PR-19:** Menu dismisses after action or when user taps elsewhere.

## 6. UX Requirements
- **UX-1:** Long-press duration matches iOS system default (~0.5 seconds).
- **UX-2:** Selection highlight color has sufficient contrast against terminal background.
- **UX-3:** Haptic feedback on long-press (to indicate selection mode started).
- **UX-4:** Context menu matches iOS system menu style where possible.

## 7. Accessibility Requirements
- **A11Y-1:** Copy and Paste actions are available via VoiceOver custom actions on the terminal view.
- **A11Y-2:** Selection state is announced by VoiceOver: "Text selected."
- **A11Y-3:** Context menu items have VoiceOver labels.

## 8. UAT Checklist
- [ ] UAT-1: Run a command that produces output (e.g., `ls -la`).
- [ ] UAT-2: Long-press on terminal text — confirm selection mode starts with highlight.
- [ ] UAT-3: Drag to extend selection — confirm highlight follows.
- [ ] UAT-4: Tap "Copy" — confirm text is copied (paste in another app to verify).
- [ ] UAT-5: Clear selection — tap elsewhere, confirm highlight disappears.
- [ ] UAT-6: Copy text in another app (e.g., Notes).
- [ ] UAT-7: Return to terminal — long-press to show context menu.
- [ ] UAT-8: Tap "Paste" — confirm text appears in terminal as input.
- [ ] UAT-9: Tap "Select All" — confirm all visible content is selected.
- [ ] UAT-10: Copy after Select All — confirm all text is copied.

## 9. Test Allocation

| Type | Scope | Method |
|------|-------|--------|
| Unit | Selection model — start, extend, clear, select all | XCTest |
| Unit | Clipboard read/write — copy to UIPasteboard, read from UIPasteboard | XCTest |
| Unit | Paste-to-input routing — clipboard text dispatched to terminal input | XCTest |
| Critical | Copy flow — select text → copy → verify clipboard contents | XCTest integration |
| Critical | Paste flow — clipboard content → paste → verify terminal input | XCTest integration |
| Full | UI-driven copy/paste round-trip (optional) | XCUITest |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. Copy extracts correct text from terminal.
3. Paste sends correct text to remote shell.
4. Selection is visually clear and adjustable.
5. No interference with normal terminal touch/input.
6. Known gaps documented before Phase 10.

## 11. Step Sequence

### S1: Implement long-press gesture recognizer on terminal view
- **Complexity:** medium
- **Deliverable:** A long-press gesture recognizer on the terminal surface that initiates selection mode at the press location.
- **Files:** `Beacon/Features/Terminal/Selection/TerminalSelectionGesture.swift`, `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** none
- **Details:** Add a `UILongPressGestureRecognizer` to the terminal view with the system-default duration (~0.5s per UX-1). On recognition, convert the touch point to a terminal character coordinate and enter selection mode. Fire haptic feedback on activation (UX-3).
- **Acceptance:**
  - [ ] Long-press on terminal activates selection mode.
  - [ ] Touch location maps to a character-boundary coordinate.
  - [ ] Haptic feedback fires on selection start.

### S2: Integrate with libghostty selection API for character-boundary selection
- **Complexity:** medium
- **Deliverable:** Selection model backed by libghostty's selection API that tracks start/end positions and selected text.
- **Files:** `Beacon/Features/Terminal/Selection/TerminalSelectionModel.swift`
- **Depends on:** S1
- **Details:** Use libghostty's selection API to create, extend, and clear text selections snapped to character boundaries. The model must support start selection at a coordinate, extend via drag (PR-3), clear on outside tap (PR-6), and select-all for visible content (PR-18). Expose selected text as a string for copy operations.
- **Acceptance:**
  - [ ] Selection starts at character boundary nearest to touch point (PR-2).
  - [ ] Drag extends selection character-by-character (PR-3).
  - [ ] Tapping outside clears selection (PR-6).
  - [ ] Select-all selects all visible terminal content (PR-18).
  - [ ] Selected text is retrievable as a plain string.

### S3: Add visual selection highlight
- **Complexity:** small
- **Deliverable:** Visual highlight overlay on the terminal surface showing the current selection.
- **Files:** `Beacon/Features/Terminal/Selection/SelectionHighlightRenderer.swift`
- **Depends on:** S2
- **Details:** Render a highlight overlay on the terminal surface matching the selection range from the selection model. The highlight color must have sufficient contrast against the terminal background (UX-2). The highlight updates in real time as the user drags to extend the selection (PR-4).
- **Acceptance:**
  - [ ] Selected text is visually highlighted with a distinct background color (PR-4).
  - [ ] Highlight has sufficient contrast against terminal background (UX-2).
  - [ ] Highlight updates in real time during drag.

### S4: Add selection handles for adjustment
- **Complexity:** medium
- **Deliverable:** Draggable start/end handles on the selection that allow the user to adjust the selection range.
- **Files:** `Beacon/Features/Terminal/Selection/SelectionHandlesView.swift`
- **Depends on:** S3
- **Details:** Display draggable handles at the start and end of the selection (PR-5). Dragging a handle updates the selection range in the selection model and the highlight in real time. Handles must be large enough for comfortable touch targeting.
- **Acceptance:**
  - [ ] Start and end handles are visible at selection boundaries (PR-5).
  - [ ] Dragging a handle adjusts the selection range.
  - [ ] Selection highlight updates as handles are dragged.

### S5: Build context menu with Copy, Paste, Select All
- **Complexity:** medium
- **Deliverable:** A context menu presented via UIEditMenuInteraction with conditional Copy, Paste, and Select All actions.
- **Files:** `Beacon/Features/Terminal/Selection/TerminalContextMenu.swift`, `Beacon/Features/Terminal/TerminalView.swift`
- **Depends on:** S2
- **Details:** Use `UIEditMenuInteraction` to present a context menu near the selection or long-press location (PR-16). Show "Copy" only when text is selected (PR-10). Show "Paste" only when clipboard has text (PR-15). Always show "Select All" (PR-17). Menu dismisses after action or when user taps elsewhere (PR-19). Match iOS system menu style (UX-4).
- **Acceptance:**
  - [ ] Context menu appears near selection/long-press location (PR-16).
  - [ ] "Copy" shown only when text is selected (PR-10).
  - [ ] "Paste" shown only when clipboard has text (PR-15).
  - [ ] "Select All" is always available (PR-17).
  - [ ] Menu dismisses after action or outside tap (PR-19).

### S6: Implement Copy to UIPasteboard
- **Complexity:** small
- **Deliverable:** Copy action that places selected text on UIPasteboard as plain text.
- **Files:** `Beacon/Features/Terminal/Selection/TerminalClipboardActions.swift`
- **Depends on:** S2, S5
- **Details:** When the user taps "Copy", retrieve the selected text from the selection model and write it to `UIPasteboard.general` as plain text (PR-8). Clear the selection after copying (PR-9). Wire the copy action to the context menu's Copy button.
- **Acceptance:**
  - [ ] Tapping "Copy" places selected text on UIPasteboard as plain text (PR-8).
  - [ ] Selection is cleared after copying (PR-9).
  - [ ] Copied text is verifiable by pasting in another app.

### S7: Implement Paste from clipboard to terminal input
- **Complexity:** small
- **Deliverable:** Paste action that reads clipboard text and sends it to the terminal input via the SSH channel.
- **Files:** `Beacon/Features/Terminal/Selection/TerminalClipboardActions.swift`
- **Depends on:** S5
- **Details:** When the user taps "Paste", read plain text from `UIPasteboard.general` (PR-12) and send it to the terminal input, which routes it to the remote shell via the SSH channel (PR-13). Paste works regardless of selection state (PR-14). Wire the paste action to the context menu's Paste button.
- **Acceptance:**
  - [ ] Tapping "Paste" reads text from UIPasteboard (PR-12).
  - [ ] Pasted text is sent to terminal input / remote shell (PR-13).
  - [ ] Paste works whether or not text is selected (PR-14).

### S8: Add VoiceOver labels for all copy/paste actions
- **Complexity:** small
- **Deliverable:** VoiceOver accessibility labels and announcements for selection state and context menu actions.
- **Files:** `Beacon/Features/Terminal/Selection/TerminalContextMenu.swift`, `Beacon/Features/Terminal/Selection/TerminalSelectionGesture.swift`
- **Depends on:** S5
- **Details:** Add VoiceOver custom actions for Copy and Paste on the terminal view (A11Y-1). Announce "Text selected." when selection is active (A11Y-2). Ensure all context menu items have VoiceOver labels (A11Y-3).
- **Acceptance:**
  - [ ] Copy and Paste available as VoiceOver custom actions (A11Y-1).
  - [ ] Selection state announced as "Text selected." (A11Y-2).
  - [ ] All context menu items have VoiceOver labels (A11Y-3).

### S9: Test copy/paste round-trip
- **Complexity:** medium
- **Deliverable:** Unit and integration tests covering selection model, clipboard operations, and the full copy/paste pipeline.
- **Files:** `BeaconTests/Unit/TerminalSelectionModelTests.swift`, `BeaconTests/Integration/CopyPasteIntegrationTests.swift`
- **Depends on:** S6, S7
- **Details:** Write unit tests for the selection model (start, extend, clear, select all) and clipboard read/write. Write critical-lane integration tests: (1) select text → copy → verify clipboard contents, (2) set clipboard → paste → verify terminal input. Connect to Docker test harness for integration tests.
- **Acceptance:**
  - [ ] Unit tests for selection model pass (start, extend, clear, select all).
  - [ ] Unit tests for clipboard read/write pass.
  - [ ] Integration test for copy flow passes against Docker harness.
  - [ ] Integration test for paste flow passes against Docker harness.

### S10: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** All UAT items verified and checked off.
- **Files:** `.ladder/specs/L-09-terminal-copy-paste.md`
- **Depends on:** S1, S2, S3, S4, S5, S6, S7, S8, S9
- **Details:** Walk through UAT-1 through UAT-10 on a device or simulator. Mark each item as passing. Document any known gaps for Phase 10.
- **Acceptance:**
  - [ ] All 10 UAT checklist items pass.
  - [ ] Known gaps (if any) documented.

## 12. References
- [terminal-engine-decision.md](../refs/terminal-engine-decision.md) — selection API
