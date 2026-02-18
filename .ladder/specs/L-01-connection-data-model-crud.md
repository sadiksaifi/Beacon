# Phase 1: Connection Data Model & CRUD

## 1. Objective
Define and implement the connection data model with full create, read, update, and delete operations. This phase establishes the persistent data layer that SSH phases build on.

## 2. Entry Criteria
1. Phase 0 accepted.
2. App shell with tabs and empty states is functional.

## 3. Scope In
1. Connection data model: host, port, username, label, auth method.
2. Local persistence (SwiftData or equivalent).
3. Connection list screen with saved connections.
4. Add/edit connection form with validation.
5. Delete connection action.
6. Auth method selector in form (UI only — actual auth implementation is Phase 3 and Phase 5).

## 4. Scope Out
1. SSH connection (Phase 3).
2. Credential storage in Keychain (Phase 3).
3. SSH key management (Phase 5).
4. Docker test harness (Phase 2).

## 5. Product Requirements
1. **PR-1:** Connection model includes: `id` (UUID), `label` (optional string), `host` (required string), `port` (integer, default 22), `username` (required string), `authMethod` (enum: password, key).
2. **PR-2:** `authMethod` is stored as part of the connection but actual credentials are NOT stored in the connection model (they go in Keychain in Phase 3/5).
3. **PR-3:** Connections persist across app launches.
4. **PR-4:** Each connection has a unique `id` generated on creation.
5. **PR-5:** Connections are displayed in a scrollable list.
6. **PR-6:** Each row shows: label (or host if no label), username, host, port.
7. **PR-7:** Empty state shows CTA to add first connection (carried from Phase 0).
8. **PR-8:** List supports swipe-to-delete.
9. **PR-9:** Tapping a connection opens the edit form.
10. **PR-10:** Required fields: host, username.
11. **PR-11:** Optional fields: label, port (defaults to 22).
12. **PR-12:** Auth method selector: Password or SSH Key (UI picker only; key selection UI comes in Phase 5).
13. **PR-13:** Save button is disabled until required fields are valid.
14. **PR-14:** Cancel action discards changes.
15. **PR-15:** Validation: host must not be empty, username must not be empty, port must be 1–65535.
16. **PR-16:** Validation errors appear inline near the relevant field.
17. **PR-17:** Save gives immediate visible success feedback (e.g., dismiss form, return to list).
18. **PR-18:** Swipe-to-delete reveals a standard iOS red destructive confirmation button.
19. **PR-19:** Deletion is immediate and permanent from the local data store.

## 6. UX Requirements
1. **UX-1:** Form submit button is disabled until required fields are valid.
2. **UX-2:** Validation errors appear near relevant fields, not as alerts.
3. **UX-3:** Save action gives immediate visible success feedback.
4. **UX-4:** Empty list state explains how to add a connection.
5. **UX-5:** "Add Connection" action is accessible from both the empty state CTA and a navigation bar button.

## 7. Accessibility Requirements
1. **A11Y-1:** Connection list rows have VoiceOver labels that read the connection name and host.
2. **A11Y-2:** Form fields have VoiceOver labels describing each field.
3. **A11Y-3:** Validation error text is announced by VoiceOver when it appears.
4. **A11Y-4:** Delete action has a VoiceOver label of "Delete connection".
5. **A11Y-5:** All text respects Dynamic Type.

## 8. UAT Checklist
- [ ] UAT-1: Launch app and see empty connections list with CTA.
- [ ] UAT-2: Tap "Add Connection" and fill in host and username.
- [ ] UAT-3: Attempt save with empty host — confirm validation error appears.
- [ ] UAT-4: Fill valid data and save — confirm connection appears in list.
- [ ] UAT-5: Create a second connection.
- [ ] UAT-6: Tap a connection to edit — confirm fields are pre-populated.
- [ ] UAT-7: Change the label and save — confirm update appears in list.
- [ ] UAT-8: Swipe to delete a connection — confirm it is removed.
- [ ] UAT-9: Kill and relaunch app — confirm remaining connection persists.
- [ ] UAT-10: Verify auth method selector shows Password and SSH Key options.

## 9. Test Allocation
| Type | Scope | Method |
|------|-------|--------|
| Unit | Connection model validation (host empty, port range, username empty) | XCTest |
| Unit | Persistence CRUD (create, read, update, delete) | XCTest |
| Unit | Connection list ordering | XCTest |
| UI (Full) | Form validation flow | XCUITest (optional) |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. Connections persist across app relaunch.
3. Form validation prevents invalid data from being saved.
4. No crashes in create/edit/delete workflows.
5. Known gaps documented before Phase 2.

## 11. Step Sequence

### S1: Define Connection model with all fields
- **Complexity:** small
- **Deliverable:** `Connection` SwiftData model and `AuthMethod` enum
- **Files:** `Beacon/Models/Connection.swift`, `Beacon/Models/AuthMethod.swift`
- **Depends on:** none
- **Details:** Define `Connection` as a `@Model` class with `id` (auto-generated UUID), `label` (optional String), `host` (String), `port` (Int, default 22), `username` (String), and `authMethod` (AuthMethod). Define `AuthMethod` as a `String` enum with `password` and `key` cases. No credential fields belong here.
- **Acceptance:**
  - [ ] `Connection` compiles with `@Model` annotation
  - [ ] All fields present with correct types and optionality (PR-1)
  - [ ] `id` auto-generates on init (PR-4)
  - [ ] `port` defaults to 22 (PR-1)
  - [ ] `label` is optional (PR-1)
  - [ ] `AuthMethod` has `.password` and `.key` cases (PR-1)

### S2: Set up SwiftData persistence layer
- **Complexity:** small
- **Deliverable:** Model container configured in the app entry point
- **Files:** `Beacon/BeaconApp.swift`
- **Depends on:** S1
- **Details:** Add `.modelContainer(for: Connection.self)` to the `WindowGroup` scene in `BeaconApp.swift`. This injects `ModelContext` into the view environment, making all CRUD operations available via `@Environment(\.modelContext)` in child views.
- **Acceptance:**
  - [ ] App builds with model container configured
  - [ ] `@Environment(\.modelContext)` resolves correctly in child views (confirmed by build)
  - [ ] App launches without crash (PR-3)

### S3: Build connection list view with empty state
- **Complexity:** medium
- **Deliverable:** Scrollable connection list with swipe-to-delete, navigation bar add button, and empty state
- **Files:** `Beacon/Views/Connections/ConnectionListView.swift`, `Beacon/Views/Connections/ConnectionsView.swift` (updated)
- **Depends on:** S2
- **Details:** Build a `List` of `Connection` objects fetched via `@Query`. Each row displays label (or host if no label), username, host, and port (PR-6). Add `.onDelete` for swipe-to-delete (PR-8). When the query is empty, render the Phase 0 empty state with CTA (PR-7). Add a navigation bar trailing button for "Add Connection" (UX-5).
- **Acceptance:**
  - [ ] Connections appear in scrollable list (PR-5)
  - [ ] Each row shows label/host, username, host, port (PR-6)
  - [ ] Empty state with CTA appears when no connections exist (PR-7, UX-4)
  - [ ] Navigation bar "Add Connection" button is present (UX-5)
  - [ ] Swipe-to-delete is available on list rows (PR-8)
  - [ ] Tapping a row triggers navigation to edit form (PR-9)

### S4: Build add/edit connection form with validation
- **Complexity:** medium
- **Deliverable:** Form-based view for adding and editing connections with inline validation
- **Files:** `Beacon/Views/Connections/ConnectionFormView.swift`
- **Depends on:** S3
- **Details:** Create a `Form`-based view usable for both add and edit. Fields: label (optional), host (required), port (default 22), username (required), auth method picker. Validate on change: host non-empty, username non-empty, port in 1–65535. Show inline validation error text below the relevant field (PR-16). Disable the Save button when validation fails (PR-13). Pre-populate fields when an existing connection is passed in.
- **Acceptance:**
  - [ ] Form contains all fields: host, username, label, port (PR-10, PR-11)
  - [ ] Save button disabled when host or username is empty (PR-13, PR-15)
  - [ ] Save button disabled when port is outside 1–65535 (PR-13, PR-15)
  - [ ] Inline validation errors appear near the relevant field (PR-16, UX-2)
  - [ ] Cancel button discards changes and dismisses (PR-14)
  - [ ] Edit mode pre-populates all fields from the existing connection (PR-9)

### S5: Implement save, update, and delete operations
- **Complexity:** small
- **Deliverable:** Working CRUD operations connected to SwiftData context
- **Files:** `Beacon/Views/Connections/ConnectionFormView.swift` (updated), `Beacon/Views/Connections/ConnectionListView.swift` (updated)
- **Depends on:** S4
- **Details:** On Save (add), insert a new `Connection` into `modelContext` and dismiss the sheet (PR-17). On Save (edit), mutate the existing model object — SwiftData tracks changes automatically. On delete, call `modelContext.delete(_:)` from the `.onDelete` handler and confirm no undo step is presented (PR-19). Deletion is permanent.
- **Acceptance:**
  - [ ] New connection appears in list immediately after save (PR-17)
  - [ ] Edited connection updates in list after save (PR-17)
  - [ ] Form dismisses after successful save (PR-17, UX-3)
  - [ ] Swipe-to-delete shows standard iOS red destructive button (PR-18)
  - [ ] Deleted connection is removed from list immediately (PR-19)

### S6: Add auth method selector (UI only)
- **Complexity:** small
- **Deliverable:** Auth method picker in the connection form
- **Files:** `Beacon/Views/Connections/ConnectionFormView.swift` (updated)
- **Depends on:** S4
- **Details:** Add a `Picker` (segmented or menu style) to the form bound to `connection.authMethod` with "Password" and "SSH Key" options. No credential collection UI is shown here — actual authentication is implemented in Phase 3 (password) and Phase 5 (SSH key).
- **Acceptance:**
  - [ ] Auth method picker appears in form with "Password" and "SSH Key" options (PR-12)
  - [ ] Selected auth method is persisted with the connection
  - [ ] No credential input fields are shown (scope out: Phase 3/5)

### S7: Add VoiceOver labels to all interactive elements
- **Complexity:** small
- **Deliverable:** Full VoiceOver and Dynamic Type coverage for connection list and form
- **Files:** `Beacon/Views/Connections/ConnectionListView.swift` (updated), `Beacon/Views/Connections/ConnectionFormView.swift` (updated)
- **Depends on:** S5, S6
- **Details:** Add `.accessibilityLabel` to list rows (connection name and host), all form fields, the delete swipe action ("Delete connection"), and Save/Cancel buttons. Ensure validation error text is present in the accessibility tree so VoiceOver announces it on appearance. Verify all text uses Dynamic Type-compatible font styles.
- **Acceptance:**
  - [ ] List rows have VoiceOver labels that read connection name and host (A11Y-1)
  - [ ] Form fields have VoiceOver labels describing each field (A11Y-2)
  - [ ] Validation error text is announced by VoiceOver when it appears (A11Y-3)
  - [ ] Delete swipe action has VoiceOver label "Delete connection" (A11Y-4)
  - [ ] All text respects Dynamic Type (A11Y-5)

### S8: Run UAT verification and relaunch test
- **Complexity:** small
- **Deliverable:** Verified UAT pass on simulator including persistence across relaunch
- **Files:** none (verification step)
- **Depends on:** S7
- **Details:** Walk through all UAT checklist items on simulator. For persistence (UAT-9), terminate the app via the home screen, relaunch, and confirm the connection list is intact. Confirm auth method selector displays correctly (UAT-10). Document any deviations before moving to Phase 2.
- **Acceptance:**
  - [ ] All UAT checklist items (UAT-1 through UAT-10) pass
  - [ ] Connections persist after app termination and relaunch (PR-3)
  - [ ] No crashes observed during create, edit, or delete workflows
