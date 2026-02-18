# Phase 0: Project Bootstrap & App Shell

## 1. Objective
Create a clean Xcode project baseline with SwiftUI app shell, tab navigation, and empty states — establishing the foundation that all subsequent phases build on.

## 2. Entry Criteria
1. Baseline — greenfield project, no predecessor phase.
2. Team agrees to UAT-first ladder model from master spec.

## 3. Scope In
1. Define iOS app project via XcodeGen `project.yml` and generate `.xcodeproj`.
2. Configure app identity, deployment target (iOS 26+), and test targets.
3. Build app shell with two tabs: Connections and Settings.
4. Add empty states with clear calls-to-action.
5. Navigation skeleton for future screens.

## 4. Scope Out
1. Connection data persistence (Phase 1).
2. SSH connectivity (Phase 3).
3. Terminal display (Phase 6).
4. Settings content beyond placeholder (Phase 14).

## 5. Product Requirements
1. **PR-1:** Define project structure in a `project.yml` and generate `.xcodeproj` using XcodeGen.
2. **PR-2:** Use SwiftUI interface and Swift language.
3. **PR-3:** Enable unit test and UI test targets from day one.
4. **PR-4:** Set deployment target to iOS 26.0.
5. **PR-5:** Project builds and runs on simulator without manual project-file fixes.
6. **PR-6:** App launches to tab view without crash.
7. **PR-7:** Tab A is labeled "Connections" with appropriate SF Symbol icon.
8. **PR-8:** Tab B is labeled "Settings" with appropriate SF Symbol icon.
9. **PR-9:** Navigation titles are visible and stable on each tab.
10. **PR-10:** Tab selection persists within the session (no unexpected tab switches).
11. **PR-11:** Connections tab shows empty state when no connections exist.
12. **PR-12:** Empty state includes text explaining what will go here.
13. **PR-13:** Empty state includes a visible call-to-action button (e.g., "Add Connection").
14. **PR-14:** CTA button navigates to a placeholder sheet indicating "Coming in Phase 1".
15. **PR-15:** Settings tab shows placeholder content (app version, build info).

## 6. UX Requirements
1. **UX-1:** Empty state CTA button is prominently placed, not buried.
2. **UX-2:** Tab bar uses standard iOS tab bar conventions.
3. **UX-3:** Navigation titles use large title style.

## 7. Accessibility Requirements
1. **A11Y-1:** Both tab bar items have VoiceOver labels matching their titles.
2. **A11Y-2:** Empty state CTA button has a descriptive VoiceOver label (e.g., "Add your first connection").
3. **A11Y-3:** All text respects Dynamic Type size preferences.

## 8. UAT Checklist
- [ ] UAT-1: Install and launch app on simulator.
- [ ] UAT-2: Confirm both tabs render and are tappable.
- [ ] UAT-3: Confirm Connections tab shows empty state with CTA.
- [ ] UAT-4: Tap CTA button and confirm placeholder sheet appears.
- [ ] UAT-5: Switch to Settings tab and confirm placeholder content is visible.
- [ ] UAT-6: Rotate device and confirm layout adapts without clipping.
- [ ] UAT-7: Enable VoiceOver and confirm all elements are navigable and labeled.

## 9. Test Allocation
| Type | Scope | Method |
|------|-------|--------|
| Unit | App launch smoke test | XCTest |
| UI (Full) | Tab navigation | XCUITest (optional) |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. App launches without crash on simulator.
3. Both tabs are functional with empty states.
4. VoiceOver labels present on all interactive elements.
5. Known gaps documented before Phase 1.

## 11. Step Sequence

### S1: Create project.yml and generate Xcode project with XcodeGen
- **Complexity:** small
- **Deliverable:** XcodeGen spec and generated Xcode project with app, unit test, and UI test targets
- **Files:** `project.yml`, `Beacon.xcodeproj`, `Beacon/BeaconApp.swift`, `Beacon/ContentView.swift`, `BeaconTests/`, `BeaconUITests/`
- **Depends on:** none
- **Details:** Write a `project.yml` defining three targets: the Beacon app (SwiftUI, iOS 26.0), BeaconTests (unit test), and BeaconUITests (UI test). Set bundle IDs, Swift version, and marketing/build version numbers in the YAML. Create the initial directory structure and stub source files (`BeaconApp.swift` with `@main`, `ContentView.swift`, test stubs). Run `xcodegen generate` to produce `Beacon.xcodeproj`. Commit both the YAML and the generated project.
- **Acceptance:**
  - [ ] `project.yml` exists at project root and defines all three targets
  - [ ] `xcodegen generate` produces `Beacon.xcodeproj` without errors
  - [ ] Project opens in Xcode without errors
  - [ ] App target, unit test target, and UI test target all exist
  - [ ] Project builds successfully with no warnings

### S2: Verify deployment target and project settings in generated project
- **Complexity:** small
- **Deliverable:** Confirmed iOS 26.0 deployment target and correct build settings across all targets
- **Files:** `project.yml`, `Beacon.xcodeproj`
- **Depends on:** S1
- **Details:** Open the generated project in Xcode and verify that the deployment target is iOS 26.0 on all three targets (app, unit tests, UI tests). Confirm bundle IDs, display name, and Swift version match `project.yml`. If any setting requires adjustment, update `project.yml` and regenerate — never edit `project.pbxproj` directly.
- **Acceptance:**
  - [ ] Deployment target is iOS 26.0 on all targets
  - [ ] App builds and runs on iOS 26 simulator
  - [ ] All settings match what is declared in `project.yml`

### S3: Build tab view with Connections and Settings tabs
- **Complexity:** small
- **Deliverable:** Tab-based navigation shell with two tabs
- **Files:** `Beacon/Views/MainTabView.swift`, `Beacon/Views/Connections/ConnectionsView.swift`, `Beacon/Views/Settings/SettingsView.swift`, `Beacon/BeaconApp.swift`
- **Depends on:** S2
- **Details:** Replace ContentView with a TabView containing Connections and Settings tabs. Each tab uses a NavigationStack with large title. Use appropriate SF Symbols for tab icons (e.g., `network` for Connections, `gear` for Settings).
- **Acceptance:**
  - [ ] Both tabs render with correct labels and icons
  - [ ] Navigation titles display in large title style
  - [ ] Tab selection works and persists within session

### S4: Add empty state view with CTA and placeholder sheet
- **Complexity:** medium
- **Deliverable:** Empty state UI on Connections tab with working CTA navigation
- **Files:** `Beacon/Views/Connections/ConnectionsEmptyStateView.swift`, `Beacon/Views/Connections/AddConnectionPlaceholderView.swift`, `Beacon/Views/Connections/ConnectionsView.swift`
- **Depends on:** S3
- **Details:** Create an empty state view with explanatory text and a prominent "Add Connection" button. Tapping the CTA presents a sheet with placeholder content indicating this feature arrives in Phase 1. The empty state should be centered and visually clear.
- **Acceptance:**
  - [ ] Empty state displays centered text and CTA button
  - [ ] CTA button is prominently placed (UX-1)
  - [ ] Tapping CTA opens placeholder sheet (PR-14)
  - [ ] Sheet can be dismissed

### S5: Add placeholder Settings content
- **Complexity:** small
- **Deliverable:** Settings tab with app version and build info
- **Files:** `Beacon/Views/Settings/SettingsView.swift`
- **Depends on:** S3
- **Details:** Display app version and build number from the main bundle in the Settings tab. Use a simple List or Form layout consistent with iOS conventions.
- **Acceptance:**
  - [ ] Settings tab shows app version string
  - [ ] Settings tab shows build number
  - [ ] Layout follows standard iOS settings conventions

### S6: Add VoiceOver labels to all interactive elements
- **Complexity:** small
- **Deliverable:** Full VoiceOver coverage for all interactive and informational elements
- **Files:** `Beacon/Views/Connections/ConnectionsEmptyStateView.swift`, `Beacon/Views/MainTabView.swift`
- **Depends on:** S4, S5
- **Details:** Add accessibility labels to tab bar items, the CTA button ("Add your first connection"), and any other interactive or informational elements. Ensure all text views support Dynamic Type.
- **Acceptance:**
  - [ ] Tab bar items have VoiceOver labels matching titles (A11Y-1)
  - [ ] CTA button has descriptive VoiceOver label (A11Y-2)
  - [ ] All text respects Dynamic Type (A11Y-3)

### S7: Add unit smoke test for app launch
- **Complexity:** small
- **Deliverable:** XCTest verifying app launches without crash
- **Files:** `BeaconTests/AppLaunchTests.swift`
- **Depends on:** S3
- **Details:** Write a minimal unit test that instantiates the app's root view and verifies it does not crash. This provides the smoke test required by the test allocation.
- **Acceptance:**
  - [ ] Test target builds and runs
  - [ ] Smoke test passes on iOS 26 simulator

### S8: Run simulator verification and UAT checklist
- **Complexity:** small
- **Deliverable:** Verified UAT pass on simulator
- **Files:** none (verification step)
- **Depends on:** S6, S7
- **Details:** Launch the app on simulator, walk through every UAT checklist item, and verify each passes. Test device rotation for layout adaptation. Run VoiceOver inspection to confirm labels.
- **Acceptance:**
  - [ ] All UAT checklist items (UAT-1 through UAT-7) pass
  - [ ] No crashes or layout issues observed

## 12. References
- [XcodeGen Usage](https://raw.githubusercontent.com/yonaskolb/XcodeGen/refs/heads/master/Docs/Usage.md)
- [XcodeGen Project Spec](https://raw.githubusercontent.com/yonaskolb/XcodeGen/refs/heads/master/Docs/ProjectSpec.md)
