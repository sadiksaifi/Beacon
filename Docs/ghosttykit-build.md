# Building GhosttyKit.xcframework

This document describes how to build the patched GhosttyKit.xcframework used by Beacon for terminal rendering.

## Prerequisites

- **Zig 0.15.2** — `brew install zig`
- **Ghostty source** at `~/Projects/ghostty/` with the iOS patches applied (see below)

## Patches Applied

Four files in the Ghostty source tree have been modified to support iOS:

| File | Change |
|------|--------|
| `src/pty.zig` | Replaced `NullPty` with `SocketPairPty`, using Unix domain socket pairs instead of a real PTY (iOS does not permit PTY allocation) |
| `src/termio/Exec.zig` | Added `threadEnterIOS()` to skip subprocess spawning, open `SocketPairPty` directly, and wire up read/write threads |
| `src/apprt/embedded.zig` | Added `ghostty_surface_pty_fd()` C API function to expose the slave FD to the host application |
| `include/ghostty.h` | Added the C header declaration for `ghostty_surface_pty_fd()` |

## Build

From the Ghostty source root:

```sh
cd ~/Projects/ghostty
zig build -Demit-xcframework -Dxcframework-target=universal --release=fast
```

The build takes roughly 5-10 minutes. Zig performs cross-compilation for all three slices simultaneously.

## Output

The built XCFramework is written to:

```
~/Projects/ghostty/macos/GhosttyKit.xcframework/
```

It contains three slices:

- `ios-arm64` — device
- `ios-arm64-simulator` — Apple Silicon simulator
- `macos-arm64_x86_64` — macOS (universal)

The uncompressed XCFramework is approximately 540 MB.

## Copying to Beacon

```sh
cp -R ~/Projects/ghostty/macos/GhosttyKit.xcframework Vendor/GhosttyKit.xcframework
```

The `Vendor/GhosttyKit.xcframework` path is tracked via Git LFS in this repository.

## Troubleshooting

- **`socketpair` APIs fail to resolve** — Verify that `std.c` imports in the patched Zig files are correct and that the Zig version matches 0.15.2.
- **Build hangs or errors on first run** — Zig may be downloading its toolchain cache. Let it complete before interrupting.
- **Stale XCFramework in Beacon** — Delete `Vendor/GhosttyKit.xcframework` before copying to avoid merging stale slices from a previous build.
