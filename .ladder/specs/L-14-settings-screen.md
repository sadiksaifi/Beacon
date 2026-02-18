# Phase 14: Settings Screen

## 1. Objective
Implement the Settings screen with user-configurable preferences for terminal, connections, and key management so users can customize app behavior and manage their SSH keys in one place.

## 2. Entry Criteria
1. Phase 13 accepted.
2. All core functionality is reliable and error-free.

## 3. Scope In
1. Terminal settings: font size adjustment.
2. Connection defaults: default port, connection timeout.
3. Key management: list stored SSH keys, delete keys.
4. About section: app version, build number.

## 4. Scope Out
1. Terminal color theme customization (non-goal for v1).
2. Custom keyboard accessory configuration.
3. iCloud sync settings.
4. Export/backup of connections or keys.

## 5. Product Requirements
- **PR-1:** Font size adjustment via slider or stepper control, range 8pt–24pt, default 14pt.
- **PR-2:** Current font size value is displayed alongside the control.
- **PR-3:** Font size changes apply to the terminal surface on next connection (or live if feasible).
- **PR-4:** Default port: numeric input field, default 22. Applied to new connections only (does not change existing).
- **PR-5:** Connection timeout: slider or stepper, range 5–60 seconds, default 15 seconds.
- **PR-6:** Changes to connection defaults apply to future connections and reconnect attempts.
- **PR-7:** List all stored SSH keys with: label, key type (Ed25519/ECDSA/RSA), creation or import date.
- **PR-8:** Tapping a key navigates to the existing Phase 5 public key detail view.
- **PR-9:** Swipe-to-delete on a key row triggers deletion from Keychain.
- **PR-10:** Delete confirmation alert: "Delete key '[label]'? This cannot be undone. Connections using this key will need a new key."
- **PR-11:** Deleting a key removes it from Keychain and silently resets any connections referencing it to password auth.
- **PR-12:** About section displays app version number, build number, and iOS version.
- **PR-13:** About section optionally includes a link to acknowledgements/licenses.

## 6. UX Requirements
- **UX-1:** Settings screen uses standard iOS grouped list style (`Form` with sections).
- **UX-2:** Changes are saved immediately — no explicit "Save" button.
- **UX-3:** Destructive actions (delete key) require confirmation before executing.
- **UX-4:** Font size preview alongside the control is ideal but not required.

## 7. Accessibility Requirements
- **A11Y-1:** All settings controls have VoiceOver labels describing the setting and current value.
- **A11Y-2:** Slider/stepper controls announce value changes to VoiceOver.
- **A11Y-3:** Key list items have VoiceOver labels with key name and type.
- **A11Y-4:** All text respects Dynamic Type.

## 8. UAT Checklist
- [ ] UAT-1: Open Settings tab — all sections visible (Terminal, Connection, Keys, About).
- [ ] UAT-2: Adjust font size — value changes are reflected in the control and persisted across relaunch.
- [ ] UAT-3: Change default port — new connections use the updated default.
- [ ] UAT-4: Change connection timeout — timeout behavior changes on next connection.
- [ ] UAT-5: View key list — all stored keys appear with label, type, and date.
- [ ] UAT-6: Tap a key — public key detail view is displayed.
- [ ] UAT-7: Delete a key — confirmation prompt appears, key is removed from list and Keychain.
- [ ] UAT-8: Verify About section shows correct app version, build number, and iOS version.

## 9. Test Allocation

| Type | Scope | Method |
|------|-------|--------|
| Unit | Settings persistence (read/write UserDefaults for font size, port, timeout) | XCTest |
| Unit | Key list data source (fetching keys from Keychain) | XCTest |
| Unit | Key deletion logic (Keychain removal + connection auth reset) | XCTest |
| Unit | Font size bounds validation (clamped to 8–24) | XCTest |
| UI (optional) | Settings flow end-to-end | XCUITest |

## 10. Exit Criteria
1. UAT checklist items pass.
2. Settings persist across app relaunch.
3. Key deletion works and updates connections appropriately.
4. No crashes in settings flow.
5. All v1 feature work is complete.

## 11. Step Sequence

### S1: Replace Settings tab placeholder with grouped settings view
- **Complexity:** medium
- **Deliverable:** A `SettingsView` with grouped sections (Terminal, Connection, Keys, About) rendered in a SwiftUI `Form`
- **Files:** `Beacon/Features/Settings/SettingsView.swift`, `Beacon/App/ContentView.swift`
- **Depends on:** none
- **Details:** Replace the existing Settings tab placeholder with a proper SwiftUI `Form` containing four sections with headers: Terminal, Connection Defaults, SSH Keys, and About. Wire it into the tab bar. Each section can start with static placeholder text; subsequent steps fill in the real controls.
- **Acceptance:**
  - [ ] Settings tab renders a grouped Form with four labeled sections
  - [ ] Tab bar navigation to Settings works correctly
  - [ ] Builds and runs without errors

### S2: Implement terminal font size setting with persistence
- **Complexity:** medium
- **Deliverable:** Font size slider/stepper in Terminal section, value persisted to UserDefaults, displayed alongside control
- **Files:** `Beacon/Features/Settings/SettingsView.swift`, `Beacon/Features/Settings/SettingsStore.swift`
- **Depends on:** S1
- **Details:** Add a `SettingsStore` (ObservableObject or `@AppStorage`) for persisting settings to UserDefaults. Add a `Slider` or `Stepper` for font size in the Terminal section, clamped to 8–24pt range with default 14pt. Display the current value as a label next to the control. The terminal surface reads this value on next connection (or live if feasible).
- **Acceptance:**
  - [ ] Font size control renders with current value displayed
  - [ ] Value is clamped to 8–24pt range
  - [ ] Value persists across app relaunch
  - [ ] Default value is 14pt on first launch

### S3: Implement default port setting with persistence
- **Complexity:** small
- **Deliverable:** Numeric input for default port in Connection section, persisted to UserDefaults
- **Files:** `Beacon/Features/Settings/SettingsView.swift`, `Beacon/Features/Settings/SettingsStore.swift`
- **Depends on:** S2
- **Details:** Add a numeric `TextField` for default port in the Connection Defaults section, defaulting to 22. Persist via SettingsStore. The connection form reads this value when creating new connections — existing connections are not affected.
- **Acceptance:**
  - [ ] Default port field renders with current value
  - [ ] Default value is 22 on first launch
  - [ ] Value persists across app relaunch
  - [ ] New connections use the configured default port

### S4: Implement connection timeout setting with persistence
- **Complexity:** small
- **Deliverable:** Slider/stepper for timeout in Connection section, range 5–60s, persisted to UserDefaults
- **Files:** `Beacon/Features/Settings/SettingsView.swift`, `Beacon/Features/Settings/SettingsStore.swift`
- **Depends on:** S2
- **Details:** Add a `Slider` or `Stepper` for connection timeout in the Connection Defaults section, range 5–60 seconds, default 15 seconds. Display current value as a label. Persist via SettingsStore. Future connection and reconnect attempts read this value.
- **Acceptance:**
  - [ ] Timeout control renders with current value displayed
  - [ ] Value is clamped to 5–60 seconds
  - [ ] Default value is 15 seconds on first launch
  - [ ] Value persists across app relaunch

### S5: Build SSH key list from Keychain
- **Complexity:** medium
- **Deliverable:** SSH Keys section displays all stored keys with label, type, and date
- **Files:** `Beacon/Features/Settings/SettingsView.swift`, `Beacon/Features/Settings/KeyListViewModel.swift`
- **Depends on:** S1
- **Details:** Create a `KeyListViewModel` that queries the Keychain for all stored SSH keys (using the same Keychain service/access-group as Phase 5). Display each key in a `List` row showing: label, key type (Ed25519/ECDSA/RSA), and creation or import date. Handle the empty state gracefully.
- **Acceptance:**
  - [ ] All stored SSH keys appear in the Keys section
  - [ ] Each row shows label, key type, and date
  - [ ] Empty state is handled (no crash, appropriate message)

### S6: Add key detail navigation to Phase 5 public key view
- **Complexity:** small
- **Deliverable:** Tapping a key row navigates to the existing public key detail view from Phase 5
- **Files:** `Beacon/Features/Settings/SettingsView.swift`
- **Depends on:** S5
- **Details:** Add a `NavigationLink` on each key row that navigates to the existing Phase 5 public key detail view, passing the selected key. Reuse the existing view — do not create a duplicate.
- **Acceptance:**
  - [ ] Tapping a key row navigates to the public key detail view
  - [ ] Public key content is displayed correctly
  - [ ] Back navigation returns to the settings key list

### S7: Implement key deletion with confirmation and Keychain removal
- **Complexity:** medium
- **Deliverable:** Swipe-to-delete on key rows with confirmation alert, Keychain removal, and connection auth reset
- **Files:** `Beacon/Features/Settings/SettingsView.swift`, `Beacon/Features/Settings/KeyListViewModel.swift`, `Beacon/Features/Connection/ConnectionStore.swift`
- **Depends on:** S5
- **Details:** Add `.onDelete` modifier to the key list for swipe-to-delete. Present a confirmation alert: "Delete key '[label]'? This cannot be undone. Connections using this key will need a new key." On confirmation, remove the key from Keychain and silently reset any connections referencing this key to password authentication.
- **Acceptance:**
  - [ ] Swipe-to-delete gesture works on key rows
  - [ ] Confirmation alert appears with correct message including key label
  - [ ] Confirming deletes the key from Keychain
  - [ ] Key disappears from the list after deletion
  - [ ] Connections referencing the deleted key are reset to password auth

### S8: Add About section with version info
- **Complexity:** small
- **Deliverable:** About section displaying app version, build number, iOS version, and optional licenses link
- **Files:** `Beacon/Features/Settings/SettingsView.swift`
- **Depends on:** S1
- **Details:** Populate the About section with app version (`CFBundleShortVersionString`), build number (`CFBundleVersion`), and iOS version (`UIDevice.current.systemVersion`). Optionally include a `NavigationLink` to an acknowledgements/licenses view if applicable.
- **Acceptance:**
  - [ ] App version is displayed and correct
  - [ ] Build number is displayed and correct
  - [ ] iOS version is displayed and correct

### S9: Add VoiceOver labels to all settings controls
- **Complexity:** small
- **Deliverable:** All settings controls have proper VoiceOver labels and value announcements
- **Files:** `Beacon/Features/Settings/SettingsView.swift`
- **Depends on:** S2, S3, S4, S5, S8
- **Details:** Add `.accessibilityLabel` and `.accessibilityValue` modifiers to all controls: font size slider/stepper, port field, timeout slider/stepper, key list rows. Ensure slider/stepper value changes announce the new value to VoiceOver. Ensure all text respects Dynamic Type.
- **Acceptance:**
  - [ ] Font size control announces setting name and current value
  - [ ] Port field has descriptive VoiceOver label
  - [ ] Timeout control announces setting name and current value
  - [ ] Key list items announce key name and type
  - [ ] All text respects Dynamic Type

### S10: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** All UAT items verified and checked off
- **Files:** `.ladder/specs/L-14-settings-screen.md`
- **Depends on:** S1, S2, S3, S4, S5, S6, S7, S8, S9
- **Details:** Walk through every item in the UAT checklist (UAT-1 through UAT-8). Verify each item passes. Check off items in this spec. Run the unit test suite to confirm all settings-related tests pass. Verify settings persist across app relaunch.
- **Acceptance:**
  - [ ] All UAT items (UAT-1 through UAT-8) pass
  - [ ] All unit tests pass
  - [ ] No crashes in settings flow
