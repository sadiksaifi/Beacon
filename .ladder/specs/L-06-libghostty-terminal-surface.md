# Phase 6: libghostty Terminal Surface

## 1. Objective
Replace the connected-state placeholder with a real terminal surface powered by libghostty so users can interact with a remote shell through a GPU-accelerated terminal emulator with Metal rendering.

## 2. Entry Criteria
1. Phase 5 accepted.
2. SSH connections (password and key auth) are functional.
3. GhosttyKit XCFramework is buildable for iOS ARM64.

## 3. Scope In
- Build GhosttyKit XCFramework for iOS (Zig build system).
- Create TerminalView (UIView subclass with CAMetalLayer).
- Wire libghostty I/O to SSH channel (Citadel).
- Shell prompt renders after successful connect.
- iOS keyboard input piped to libghostty → remote shell.
- Output renders in real-time via Metal.
- Basic keyboard show/hide handling.

## 4. Scope Out
- Terminal resize on rotation (Phase 7).
- Accessory key bar (Phase 8).
- Copy/paste (Phase 9).
- iOS lifecycle/reconnect (Phase 10).
- tmux (Phases 11-12).

## 5. Product Requirements
- **PR-1:** Build libghostty using Zig for iOS ARM64 target.
- **PR-2:** Package as XCFramework with C headers.
- **PR-3:** Add XCFramework to Xcode project as binary dependency.
- **PR-4:** Document exact build steps and Zig version required.
- **PR-5:** Build process is reproducible from a clean checkout.
- **PR-6:** Create `TerminalView` as a UIView subclass.
- **PR-7:** TerminalView owns a CAMetalLayer for GPU-accelerated rendering.
- **PR-8:** TerminalView is wrapped in UIViewRepresentable for SwiftUI integration.
- **PR-9:** Terminal view appears after successful SSH connection (replaces connected-state placeholder).
- **PR-10:** Terminal view fills the available screen area (minus safe area insets and keyboard).
- **PR-11:** Data received from SSH channel (Citadel) is written to libghostty input.
- **PR-12:** Data produced by libghostty output is sent to SSH channel.
- **PR-13:** I/O bridge handles backpressure without blocking the UI thread.
- **PR-14:** I/O bridge cleans up when connection closes.
- **PR-15:** Shell prompt renders within 1 second of connection establishment.
- **PR-16:** Terminal output updates in real-time as data arrives from the SSH channel.
- **PR-17:** Cursor is visible and positioned correctly.
- **PR-18:** Basic text colors and attributes render correctly (bold, dim, standard ANSI colors).
- **PR-19:** Rendering maintains 60fps for normal shell output.
- **PR-20:** iOS software keyboard appears when terminal view is focused.
- **PR-21:** Character input from keyboard is delivered to libghostty via `ghostty_surface_key()`.
- **PR-22:** Standard characters (letters, numbers, symbols) produce correct remote shell input.
- **PR-23:** Return key sends newline/enter to remote shell.
- **PR-24:** Backspace key works for character deletion.
- **PR-25:** When keyboard appears, terminal view resizes to avoid overlap.
- **PR-26:** When keyboard hides, terminal view expands to fill available space.
- **PR-27:** Keyboard appearance/disappearance does not cause crashes or rendering artifacts.
- **PR-28:** Bulk output (e.g., `cat large_file.txt`, `find /`) may drop frames but must not hang or crash.
- **PR-29:** Terminal buffer memory stays bounded (libghostty manages scrollback limits).

## 6. UX Requirements
- **UX-1:** User sees shell prompt shortly after connection — no blank screen.
- **UX-2:** Typing feels responsive — input-to-screen latency under 50ms under normal conditions.
- **UX-3:** Terminal background and text colors provide sufficient contrast.
- **UX-4:** Connection loss during terminal use transitions to clear error state (not blank screen).

## 7. Accessibility Requirements
- **A11Y-1:** Terminal view has a VoiceOver label: "Terminal — connected to [host]".
- **A11Y-2:** Connection state changes are announced by VoiceOver.
- **A11Y-3:** VoiceOver reading of terminal content is a known limitation of GPU-rendered terminals and is not required for v1.

## 8. UAT Checklist
- [ ] UAT-1: Connect to Docker harness — confirm shell prompt renders in terminal surface.
- [ ] UAT-2: Type `pwd` and press Return — confirm command appears and output renders.
- [ ] UAT-3: Type `ls -la` — confirm multi-line output renders correctly.
- [ ] UAT-4: Type `echo hello world` — confirm output matches.
- [ ] UAT-5: Run `top` — confirm live-updating output renders (press `q` to quit).
- [ ] UAT-6: Verify cursor is visible and moves as expected.
- [ ] UAT-7: Verify keyboard appears when terminal is tapped.
- [ ] UAT-8: Verify terminal resizes when keyboard appears/hides.
- [ ] UAT-9: Disconnect (server-side or network) — confirm error state appears, not blank screen.
- [ ] UAT-10: Verify basic ANSI colors render in output (e.g., `ls --color`).

## 9. Test Allocation
| Type | Scope | Method |
|------|-------|--------|
| Unit | I/O bridge data flow (bidirectional relay) | XCTest |
| Unit | Terminal view lifecycle (create, attach, teardown) | XCTest |
| Unit | Keyboard visibility handling (resize logic) | XCTest |
| Critical | Connect → render → input roundtrip against Docker harness | XCTest (integration) |
| Critical | Disconnect error display | XCTest (integration) |
| Full | Broader terminal rendering (escape sequences, colors, scrollback) | XCTest (integration) |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. Terminal surface renders shell output reliably.
3. Keyboard input reaches remote shell.
4. Rendering performance meets expectations for normal usage.
5. No blank screen or crash on connect or disconnect.
6. Known gaps documented before Phase 7.

## 11. Step Sequence

### S1: Build GhosttyKit XCFramework for iOS ARM64
- **Complexity:** large
- **Deliverable:** `GhosttyKit.xcframework` built via Zig targeting iOS ARM64, containing the compiled libghostty static library and C headers
- **Files:** `Scripts/build-ghosttykit.sh`, `Vendor/GhosttyKit.xcframework/`
- **Depends on:** none
- **Details:** Set up the Zig build invocation targeting `aarch64-ios` (or the equivalent Zig triple for iOS ARM64). Configure the build to produce a static library and export the C headers needed by Swift (at minimum: `ghostty_surface_*` functions, configuration types, and I/O callback signatures). Package the output into an XCFramework structure. The build script should be runnable from the repo root.
- **Acceptance:**
  - [ ] `build-ghosttykit.sh` runs to completion and produces `GhosttyKit.xcframework`
  - [ ] XCFramework contains a static library for iOS ARM64 (PR-1)
  - [ ] C headers are included in the framework (PR-2)
  - [ ] Build is reproducible from a clean checkout (PR-5)

### S2: Document Zig build steps and version requirements
- **Complexity:** small
- **Deliverable:** Build documentation specifying the exact Zig version, dependencies, and step-by-step instructions to reproduce the XCFramework build
- **Files:** `Docs/ghosttykit-build.md`
- **Depends on:** S1
- **Details:** Document the required Zig version (pinned), any system dependencies (e.g., Xcode CLI tools, macOS SDK), environment setup, and the exact commands to build GhosttyKit from a clean checkout. Include troubleshooting notes for common build failures. This is the authoritative reference for anyone rebuilding the framework.
- **Acceptance:**
  - [ ] Exact Zig version is specified (PR-4)
  - [ ] Step-by-step build instructions are complete and accurate (PR-4)
  - [ ] A new contributor can follow the doc and produce the XCFramework (PR-5)

### S3: Add XCFramework to Xcode project as binary dependency
- **Complexity:** small
- **Deliverable:** GhosttyKit.xcframework linked into the Beacon Xcode project so that `import GhosttyKit` compiles
- **Files:** `Beacon.xcodeproj/` (updated)
- **Depends on:** S1
- **Details:** Add the XCFramework to the Xcode project as an embedded binary framework. Configure the build settings so the C headers are visible to Swift via a bridging header or module map. Verify that a Swift file can `import` the GhosttyKit module and reference its types without errors.
- **Acceptance:**
  - [ ] XCFramework is added as a binary dependency in Xcode (PR-3)
  - [ ] `import GhosttyKit` compiles in a Swift file
  - [ ] Project builds cleanly for iOS simulator and device targets

### S4: Create TerminalView UIView subclass with CAMetalLayer
- **Complexity:** medium
- **Deliverable:** `TerminalView` — a UIView subclass that initializes a CAMetalLayer and creates a libghostty surface for Metal-based terminal rendering
- **Files:** `Beacon/Views/Terminal/TerminalView.swift`
- **Depends on:** S3
- **Details:** Create `TerminalView` as a UIView subclass. Override `layerClass` (or configure in `init`) to use `CAMetalLayer`. In `init`, create a libghostty surface via the C API (e.g., `ghostty_surface_new()`) attached to the Metal layer. Set up the render callback so libghostty draws frames to the Metal layer. Handle the view lifecycle: initialize the surface on creation, tear it down on `removeFromSuperview` or `deinit`. Set a default terminal size (columns/rows) based on the view's bounds and a reasonable cell size.
- **Acceptance:**
  - [ ] `TerminalView` is a UIView subclass (PR-6)
  - [ ] Owns a CAMetalLayer for GPU rendering (PR-7)
  - [ ] libghostty surface is created and attached to the Metal layer
  - [ ] View cleans up the surface on teardown
  - [ ] Project builds cleanly

### S5: Create UIViewRepresentable wrapper for SwiftUI
- **Complexity:** small
- **Deliverable:** `TerminalSurface` — a UIViewRepresentable that wraps `TerminalView` for use in SwiftUI view hierarchies
- **Files:** `Beacon/Views/Terminal/TerminalSurface.swift`
- **Depends on:** S4
- **Details:** Create `TerminalSurface` conforming to `UIViewRepresentable`. In `makeUIView`, instantiate and return a `TerminalView`. In `updateUIView`, propagate any relevant state changes (e.g., connection info for the VoiceOver label). Use a `Coordinator` if needed for delegate callbacks. The wrapper should pass through the I/O bridge and connection context so the terminal can send/receive data.
- **Acceptance:**
  - [ ] `TerminalSurface` wraps `TerminalView` via UIViewRepresentable (PR-8)
  - [ ] Can be placed in a SwiftUI view hierarchy and renders
  - [ ] Propagates state changes from SwiftUI to TerminalView
  - [ ] Project builds cleanly

### S6: Create I/O bridge between SSH channel and libghostty
- **Complexity:** large
- **Deliverable:** `TerminalIOBridge` — a service that relays data bidirectionally between the Citadel SSH channel and the libghostty surface, with backpressure handling and cleanup
- **Files:** `Beacon/Services/TerminalIOBridge.swift`
- **Depends on:** S4
- **Details:** Create `TerminalIOBridge` with two data paths: (1) SSH channel → libghostty: read data from the Citadel channel's output stream and write it to the libghostty surface input via the C API; (2) libghostty → SSH channel: register a write callback with libghostty that forwards output bytes to the Citadel channel. Both paths must operate off the main thread to avoid blocking the UI (PR-13). Implement backpressure by buffering or throttling if either side can't keep up. On connection close (channel EOF or error), tear down both paths, notify the UI layer, and release resources (PR-14).
- **Acceptance:**
  - [ ] SSH channel data flows to libghostty input (PR-11)
  - [ ] libghostty output flows to SSH channel (PR-12)
  - [ ] I/O runs off the main thread — UI remains responsive (PR-13)
  - [ ] Bridge cleans up on connection close (PR-14)
  - [ ] Bulk output does not hang or crash (PR-28)

### S7: Wire terminal view into SSH connection flow
- **Complexity:** medium
- **Deliverable:** Terminal surface appears after successful SSH connection, replacing the connected-state placeholder, with the I/O bridge connecting the SSH channel to the terminal
- **Files:** `Beacon/Views/Terminal/TerminalSurface.swift` (updated), `Beacon/Views/Connections/ConnectedView.swift` (updated)
- **Depends on:** S5, S6
- **Details:** In the existing connection flow, replace the connected-state placeholder view with `TerminalSurface`. On successful SSH connection, instantiate a `TerminalIOBridge` with the Citadel SSH channel and the `TerminalView`'s libghostty surface, then start the bridge. The terminal should fill the available screen area minus safe area insets (PR-10). Verify that the shell prompt renders after the bridge starts (PR-15).
- **Acceptance:**
  - [ ] Terminal surface replaces the connected-state placeholder (PR-9)
  - [ ] Terminal fills the available screen area (PR-10)
  - [ ] Shell prompt renders within 1 second of connection (PR-15)
  - [ ] Terminal output updates in real-time (PR-16)

### S8: Implement connection-loss error state
- **Complexity:** small
- **Deliverable:** Error state UI that appears when the SSH connection drops during an active terminal session, replacing the terminal surface with a clear error message
- **Files:** `Beacon/Services/TerminalIOBridge.swift` (updated), `Beacon/Views/Connections/ConnectedView.swift` (updated)
- **Depends on:** S7
- **Details:** When the I/O bridge detects a connection close (channel EOF, network error, or server disconnect), it should signal the UI layer. The connection view transitions from the terminal surface to an error state showing a clear message (e.g., "Connection lost"). The terminal surface and I/O bridge are torn down cleanly. This must never result in a blank screen or crash (UX-4).
- **Acceptance:**
  - [ ] Connection loss shows a clear error state, not a blank screen (UX-4)
  - [ ] I/O bridge and terminal surface are torn down cleanly
  - [ ] No crashes on server-side or network disconnect
  - [ ] State change is announced by VoiceOver (A11Y-2)

### S9: Implement keyboard input capture and delivery to libghostty
- **Complexity:** medium
- **Deliverable:** Keyboard input handling in `TerminalView` that captures iOS software keyboard input and delivers it to libghostty via `ghostty_surface_key()`
- **Files:** `Beacon/Views/Terminal/TerminalView.swift` (updated)
- **Depends on:** S7
- **Details:** Make `TerminalView` the first responder and conform to `UIKeyInput` (or a suitable protocol) so the iOS software keyboard targets it. Implement `insertText(_:)` to deliver character input to libghostty via `ghostty_surface_key()` (or the appropriate C API function). Implement `deleteBackward()` to send the backspace key event. Handle the Return key to send newline/enter. Override `canBecomeFirstResponder` to return `true`. Standard characters, numbers, and symbols should all produce correct input (PR-22).
- **Acceptance:**
  - [ ] iOS software keyboard appears when terminal view is focused (PR-20)
  - [ ] Character input is delivered via `ghostty_surface_key()` (PR-21)
  - [ ] Standard characters produce correct remote shell input (PR-22)
  - [ ] Return key sends newline/enter (PR-23)
  - [ ] Backspace key deletes characters (PR-24)

### S10: Handle keyboard show/hide with terminal view resize
- **Complexity:** medium
- **Deliverable:** Keyboard-aware layout that resizes the terminal view when the iOS keyboard appears or disappears, notifying libghostty of the new terminal dimensions
- **Files:** `Beacon/Views/Terminal/TerminalSurface.swift` (updated)
- **Depends on:** S9
- **Details:** Observe `UIResponder.keyboardWillShowNotification` and `keyboardWillHideNotification` to detect keyboard transitions. When the keyboard appears, reduce the terminal view's height by the keyboard height. When it hides, expand back to fill available space. After resizing, recalculate the terminal's column/row count and notify libghostty of the new size (e.g., `ghostty_surface_set_size()`). Animate the resize to match the keyboard animation duration and curve. Ensure no rendering artifacts during the transition (PR-27).
- **Acceptance:**
  - [ ] Terminal resizes when keyboard appears (PR-25)
  - [ ] Terminal expands when keyboard hides (PR-26)
  - [ ] No crashes or rendering artifacts during transitions (PR-27)
  - [ ] libghostty is notified of new terminal dimensions
  - [ ] Cursor and content remain correctly positioned after resize

### S11: Add VoiceOver labels and accessibility announcements
- **Complexity:** small
- **Deliverable:** Accessibility coverage for the terminal view including VoiceOver label and connection state announcements
- **Files:** `Beacon/Views/Terminal/TerminalSurface.swift` (updated), `Beacon/Views/Terminal/TerminalView.swift` (updated)
- **Depends on:** S7
- **Details:** Set `accessibilityLabel` on `TerminalView` to "Terminal — connected to [host]" where `[host]` is the connection's hostname (A11Y-1). Post `UIAccessibility.Notification.announcement` when the connection state changes (connected, disconnected, error) so VoiceOver announces transitions (A11Y-2). Note that reading terminal content via VoiceOver is a known limitation and not required (A11Y-3).
- **Acceptance:**
  - [ ] Terminal view has VoiceOver label "Terminal — connected to [host]" (A11Y-1)
  - [ ] Connection state changes are announced via VoiceOver (A11Y-2)
  - [ ] Known limitation for terminal content reading is accepted (A11Y-3)

### S12: Write unit tests for I/O bridge and keyboard handling
- **Complexity:** medium
- **Deliverable:** XCTest unit tests covering the I/O bridge data flow, terminal view lifecycle, and keyboard visibility resize logic
- **Files:** `BeaconTests/TerminalIOBridgeTests.swift`, `BeaconTests/TerminalViewTests.swift`
- **Depends on:** S10
- **Details:** Write unit tests for: (1) I/O bridge — verify data written to the SSH-side input appears at the libghostty-side output and vice versa, using mock/stub channels; verify cleanup on close. (2) Terminal view lifecycle — verify the view creates and tears down the libghostty surface correctly. (3) Keyboard handling — verify the resize calculation produces correct terminal dimensions when keyboard height changes. Use mocks for the libghostty C API where needed.
- **Acceptance:**
  - [ ] I/O bridge bidirectional data flow tests pass
  - [ ] I/O bridge cleanup on close test passes
  - [ ] Terminal view lifecycle tests pass
  - [ ] Keyboard resize calculation tests pass
  - [ ] All tests build and run in the BeaconTests target

### S13: Write integration tests against Docker harness
- **Complexity:** medium
- **Deliverable:** XCTest integration tests for the terminal connect → render → input roundtrip and disconnect error display, runnable against the Docker test harness
- **Files:** `BeaconTests/TerminalIntegrationTests.swift`
- **Depends on:** S12
- **Details:** Write integration tests: (1) Connect to Docker harness, verify the shell prompt renders (data received from SSH channel reaches libghostty). (2) Send a command (`echo test`), verify the expected output appears in the SSH channel response. (3) Trigger a server-side disconnect, verify the error state is surfaced (not blank screen). Guard each test with a precondition check for harness availability and skip gracefully if not reachable.
- **Acceptance:**
  - [ ] Connect → render roundtrip test passes against Docker harness
  - [ ] Input → output roundtrip test passes (echo command)
  - [ ] Disconnect error display test passes
  - [ ] Tests skip gracefully when Docker harness is not reachable

### S14: Execute UAT checklist
- **Complexity:** small
- **Deliverable:** Verified UAT pass on simulator against the Docker test harness
- **Files:** none (verification step)
- **Depends on:** S13
- **Details:** Walk through all 10 UAT checklist items on the iOS simulator with the Docker harness running. Verify shell prompt rendering, command execution and output, live-updating output (`top`), cursor visibility, keyboard appearance, terminal resize on keyboard show/hide, disconnect error state, and ANSI color rendering. Document any deviations or known gaps before starting Phase 7.
- **Acceptance:**
  - [ ] All UAT checklist items (UAT-1 through UAT-10) pass
  - [ ] No crashes or stuck states observed
  - [ ] Known gaps documented before Phase 7

## 12. References
- [terminal-engine-decision.md](../refs/terminal-engine-decision.md)
