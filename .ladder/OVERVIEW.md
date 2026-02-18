# Beacon — Product Overview

## Vision
A native iOS SSH client with a fast terminal and seamless tmux integration.

## Tech Stack
- Swift + SwiftUI (iOS 26.0+)
- Citadel (SwiftNIO SSH) for SSH transport
- libghostty (GhosttyKit XCFramework via Zig) for terminal rendering with Metal
- SwiftData for local persistence
- iOS Keychain with biometric access control for credentials and keys
- NWPathMonitor for network awareness
- Docker for test harness
- Xcode + SPM + Zig build toolchain

## Architecture
SwiftUI app shell with tab-based navigation, backed by SwiftData for connection persistence and iOS Keychain for credential/key storage. SSH transport via Citadel (SwiftNIO SSH) feeds a libghostty terminal surface rendered through Metal on a CAMetalLayer. iOS lifecycle events drive a disconnect/snapshot/reconnect cycle with NWPathMonitor for network awareness and automatic tmux reattach.

## Reference Docs
| Document | Relevant Phases |
|----------|----------------|
| terminal-engine-decision.md | L-06, L-07, L-08, L-09 |
| ssh-library-decision.md | L-03, L-05 |
| ios-lifecycle-strategy.md | L-10, L-12 |
| security-architecture.md | L-03, L-04, L-05 |

## Phase Registry
| # | File | Status |
|---|------|--------|
| 0 | L-00-project-bootstrap-app-shell.md | done |
| 1 | L-01-connection-data-model-crud.md | done |
| 2 | L-02-docker-test-harness.md | done |
| 3 | L-03-ssh-connect-password-auth.md | done |
| 4 | L-04-host-key-verification-trust.md | done |
| 5 | L-05-ssh-key-management-auth.md | done |
| 6 | L-06-libghostty-terminal-surface.md | done |
| 7 | L-07-terminal-resize-orientation.md | pending |
| 8 | L-08-keyboard-accessory-bar.md | pending |
| 9 | L-09-terminal-copy-paste.md | pending |
| 10 | L-10-ios-lifecycle-reconnection.md | pending |
| 11 | L-11-tmux-core.md | pending |
| 12 | L-12-tmux-reconnect-reattach.md | pending |
| 13 | L-13-reliability-hardening.md | pending |
| 14 | L-14-settings-screen.md | pending |
