# Reference: Terminal Engine Decision

## 1. Context
Beacon needs a terminal emulator engine for rendering shell output on iOS. The engine must:
- Render VT100/VT220/xterm escape sequences accurately
- Support Metal rendering for performance on iOS
- Handle terminal resize events
- Support text selection for copy operations
- Be embeddable in a UIKit/SwiftUI view hierarchy
- Work without a local PTY (all I/O comes from a remote SSH channel)

## 2. Decision

**Use libghostty** (GhosttyKit) as the terminal rendering engine.

## 3. What is libghostty
libghostty is the core terminal emulation and rendering library extracted from Ghostty, a terminal emulator created by Mitchell Hashimoto. It is written in Zig with a C API surface, designed for embedding in host applications.

Key capabilities:
- Comprehensive VT terminal emulation (xterm-256color compatible)
- Metal-based rendering via CAMetalLayer
- GPU-accelerated text rendering
- Built-in text selection model
- Surface abstraction that separates I/O from rendering
- Designed for embedding — host app provides the view, keyboard, and I/O

## 4. iOS Integration Approach

### 4.1 Build Process
1. libghostty is built using Zig's build system (`zig build`)
2. Target: Apple iOS ARM64
3. Output: static library + headers, packaged as XCFramework
4. XCFramework is added to the Xcode project as a binary dependency
5. Build must be performed on macOS with Zig toolchain installed

### 4.2 View Architecture
```
┌─────────────────────────────┐
│ SwiftUI View Host           │
│  ┌───────────────────────┐  │
│  │ UIViewRepresentable   │  │
│  │  ┌─────────────────┐  │  │
│  │  │ TerminalView     │  │  │
│  │  │ (UIView subclass)│  │  │
│  │  │  ┌────────────┐  │  │  │
│  │  │  │CAMetalLayer│  │  │  │
│  │  │  └────────────┘  │  │  │
│  │  └─────────────────┘  │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

- **TerminalView**: UIView subclass that owns a CAMetalLayer
- **CAMetalLayer**: Metal rendering surface managed by libghostty
- **UIViewRepresentable**: Bridge to SwiftUI view hierarchy
- libghostty drives rendering directly to the Metal layer

### 4.3 Host App Responsibilities
The host application (Beacon) is responsible for:
1. **Keyboard input**: Capture UIKit key events and deliver to libghostty via `ghostty_surface_key()`
2. **Touch events**: Handle touch for text selection, deliver to libghostty surface
3. **I/O bridge**: Read from SSH channel → write to libghostty input; read libghostty output → write to SSH channel
4. **Resize**: On view layout changes, call `ghostty_surface_set_size()` with new dimensions
5. **Lifecycle**: Create and destroy libghostty surface with terminal view lifecycle

### 4.4 I/O Flow
```
SSH Channel (Citadel)          libghostty              Screen
     │                            │                       │
     │──── channel data ─────────>│                       │
     │                            │── Metal render ──────>│
     │                            │                       │
     │<─── terminal output ───────│                       │
     │                            │<── key events ────────│
     │                            │<── touch events ──────│
```

## 5. Known Limitations

### 5.1 No Local PTY
iOS does not allow spawning local PTY devices. libghostty's I/O must be driven entirely by the SSH channel data stream. This is a supported configuration — libghostty separates its terminal emulation from PTY management.

### 5.2 Unstable Embedding API
libghostty's C API is not yet formally stabilized. Function signatures and configuration structures may change between releases.

**Mitigation:** Pin to a specific Ghostty commit/tag. Wrap all libghostty calls in a Swift abstraction layer (`TerminalEngine` protocol) so API changes are isolated to one file.

### 5.3 Build Complexity
Building libghostty for iOS requires:
- Zig toolchain (specific version pinned in build docs)
- Cross-compilation targeting iOS ARM64
- XCFramework packaging step

**Mitigation:** Document the exact build steps. Consider caching the built XCFramework in the repo or CI artifacts to avoid rebuilding on every development cycle.

### 5.4 Text Input on iOS
iOS software keyboard input must be captured via UIKit's key input responder chain and translated to libghostty key events. This is non-trivial and requires careful handling of:
- Standard character input
- Special keys (arrows, tab, escape) via the accessory bar
- Modifier keys (Ctrl)
- IME/composition input (deferred for v1)

## 6. Why Not Alternatives

| Alternative | Reason for rejection |
|---|---|
| SwiftTerm | Pure Swift, but limited VT support, no Metal rendering, no GPU acceleration |
| Custom terminal emulator | Months of work to reach libghostty's VT compliance level |
| WebView-based (xterm.js) | Performance overhead, not native, poor integration with iOS input |
| Raw text view (Phase 2 approach) | Not a real terminal — no cursor, no escape sequences, no colors |

## 7. Performance Expectations
- Terminal output rendering should maintain 60fps for normal shell output
- Bulk output (e.g., `cat large_file.txt`) may drop frames but must not hang
- Input-to-screen latency should be imperceptible (<50ms) under normal conditions
- Memory usage for terminal buffer should remain bounded (libghostty manages scrollback limits)

## 8. Referenced By
- [Phase 6: libghostty Terminal Surface](../specs/L-06-libghostty-terminal-surface.md)
- [Phase 7: Terminal Resize & Orientation](../specs/L-07-terminal-resize-orientation.md)
- [Phase 8: Keyboard Accessory Bar](../specs/L-08-keyboard-accessory-bar.md)
- [Phase 9: Terminal Copy & Paste](../specs/L-09-terminal-copy-paste.md)
