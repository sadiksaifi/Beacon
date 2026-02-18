# Reference: SSH Library Decision

## 1. Context
Beacon is an iOS SSH client requiring a native SSH library for Swift/iOS. The library must support:
- Password authentication
- Public key authentication (Ed25519, ECDSA P-256, RSA)
- Channel multiplexing (for future tmux control channel)
- Integration with Swift concurrency (async/await)
- SPM (Swift Package Manager) compatibility
- iOS 17+ deployment target

## 2. Libraries Evaluated

### 2.1 SwiftNIO SSH (apple/swift-nio-ssh)
- **Maintainer:** Apple
- **License:** Apache 2.0
- **Pros:** Apple-maintained, pure Swift, async/await native, SPM native, strong cryptographic foundation
- **Cons:** Low-level transport only — no high-level client API, no built-in auth flows, no channel abstractions, significant integration effort required
- **Verdict:** Too low-level for direct use. Better as a foundation layer.

### 2.2 Citadel (orlandos-nl/Citadel)
- **Maintainer:** Joannis Kolkman (orlandos-nl)
- **License:** MIT
- **Pros:** Built on SwiftNIO SSH, provides high-level client API, async/await native, SPM native, supports password and public key auth, SFTP support (unused but present), channel multiplexing, actively maintained
- **Cons:** No keyboard-interactive auth support (SwiftNIO SSH limitation), RSA key support requires using a fork or extension, smaller community than libssh2
- **Verdict:** Best fit for Beacon's requirements.

### 2.3 libssh2 (via CSSH or SwiftSH)
- **Maintainer:** libssh2 project (C library), various Swift wrappers
- **License:** BSD
- **Pros:** Mature, widely used, supports all auth methods including keyboard-interactive, extensive protocol coverage
- **Cons:** C library requiring bridging header or XCFramework, not async/await native, manual memory management concerns, Swift wrappers (SwiftSH, CSSH) are often unmaintained or incomplete, no SPM native support without custom Package.swift
- **Verdict:** Viable fallback but integration friction is high.

### 2.4 libssh (via C bridging)
- **Maintainer:** libssh project (C library)
- **License:** LGPL 2.1
- **Pros:** Full protocol support, keyboard-interactive, agent forwarding
- **Cons:** LGPL license complicates App Store distribution (dynamic linking required), C bridging, not async/await compatible, no maintained Swift wrapper
- **Verdict:** License and integration issues disqualify it.

### 2.5 NMSSH
- **Maintainer:** Nine Muses (community)
- **License:** MIT
- **Cons:** Unmaintained since ~2020, depends on libssh2, Objective-C API, no async/await, no SPM support
- **Verdict:** Disqualified due to abandonment.

## 3. Decision

**Use Citadel (orlandos-nl/Citadel)** as the SSH library.

## 4. Rationale
1. **Pure Swift + SPM native** — no bridging headers, no XCFramework builds, clean dependency graph.
2. **Built on Apple's SwiftNIO SSH** — inherits Apple's cryptographic and transport implementation.
3. **High-level client API** — connection, authentication, and channel management out of the box.
4. **Async/await native** — natural fit with Swift concurrency and SwiftUI lifecycle.
5. **Channel multiplexing** — required for tmux control mode and future multi-channel scenarios.
6. **MIT licensed** — no App Store distribution concerns.

## 5. Known Gaps

### 5.1 No Keyboard-Interactive Auth
Citadel (and SwiftNIO SSH) do not support keyboard-interactive authentication. This is a protocol-level limitation in the underlying SwiftNIO SSH implementation.

**Impact:** Some servers configured for keyboard-interactive-only auth will not work. Password auth and public key auth cover the vast majority of use cases.

**Mitigation:** Keyboard-interactive is listed as a non-goal for v1. If needed in the future, options include:
- Contributing keyboard-interactive support upstream to SwiftNIO SSH
- Falling back to libssh2 for specific connections
- Wrapping a C library for keyboard-interactive only

### 5.2 RSA Key Support
The mainline Citadel release has limited RSA support. Ed25519 and ECDSA work out of the box.

**Mitigation:** Use Ed25519 as the default key type for generation. For RSA import, evaluate Citadel forks that add RSA support or extend SwiftNIO SSH's RSA handling. RSA is supported for server host keys; the gap is primarily for client authentication keys.

## 6. Fallback Plan
If Citadel proves insufficient during implementation:
1. First attempt: contribute fixes upstream or maintain a thin fork.
2. Second attempt: drop to raw SwiftNIO SSH and build the high-level layer manually.
3. Last resort: integrate libssh2 via XCFramework with async/await wrapper.

## 7. Referenced By
- [Phase 3: SSH Connect & Password Auth](../specs/L-03-ssh-connect-password-auth.md)
- [Phase 5: SSH Key Management & Key Auth](../specs/L-05-ssh-key-management-auth.md)
- [Phase 6: libghostty Terminal Surface](../specs/L-06-libghostty-terminal-surface.md) (channel I/O)
