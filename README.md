# Beacon

A native iOS SSH client with a fast terminal and seamless tmux integration.

> [!WARNING]
> Beacon is in early development and is not yet ready for production use. Expect incomplete features, breaking changes, and rough edges. Use at your own risk.

## About

Beacon is an SSH client built from scratch for iOS using Swift and SwiftUI. It pairs a GPU-accelerated terminal (powered by libghostty and Metal) with first-class tmux support, so backgrounding your app doesn't mean losing your session. Credentials stay on-device in the iOS Keychain with biometric protection — nothing syncs to iCloud.

The project is in active early development.

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6.2+, strict concurrency |
| UI | SwiftUI (iOS 26.0+) |
| SSH transport | [Citadel](https://github.com/orlandos-nl/Citadel) (SwiftNIO SSH) |
| Terminal rendering | libghostty (GhosttyKit) via Metal / CAMetalLayer |
| Persistence | SwiftData |
| Secrets | iOS Keychain with biometric access control |
| Network awareness | NWPathMonitor |
| Build tooling | Xcode + SPM + XcodeGen + Zig (for libghostty) |

## Requirements

- iOS 26.0+
- Xcode 26+

## Getting Started

Beacon uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`.

```bash
# Clone the repository
git clone https://github.com/your-username/Beacon.git
cd Beacon

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open Beacon.xcodeproj
```

Build and run on a simulator or device from Xcode.

## Architecture Decisions

**Citadel over libssh2** — Pure Swift, async/await native, built on Apple's SwiftNIO SSH. Avoids C bridging headers and manual memory management. MIT licensed with no App Store concerns.

**libghostty over SwiftTerm** — Metal-based GPU rendering, comprehensive VT emulation (xterm-256color), built-in text selection. Written in Zig with a C API designed for embedding.

**Keychain-only secrets** — Passwords and private keys are stored exclusively in the iOS Keychain with biometric access control. No custom encryption layer on top (redundant with hardware-backed Keychain encryption).

**No iCloud sync** — Credentials are deliberately kept on-device only. `kSecAttrSynchronizable` is set to `false` for all Keychain items.

**Accept iOS backgrounding constraints** — iOS kills TCP connections when apps suspend. Rather than fighting the platform with VPN tricks, Beacon disconnects gracefully on background and reconnects quickly on foreground, relying on tmux for session persistence. This is the approach used by every major iOS SSH client.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
