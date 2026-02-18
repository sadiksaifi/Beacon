# Reference: iOS Lifecycle & Backgrounding Strategy

## 1. Context
iOS aggressively manages background app execution. TCP connections (including SSH) are killed when apps are suspended. This is a fundamental platform constraint that affects every iOS SSH client.

Beacon must define a clear strategy for what happens when the user:
- Switches to another app
- Locks the device
- Returns to Beacon after suspension
- Loses network connectivity while foregrounded

## 2. iOS Background Execution Constraints

### 2.1 What Happens When an App Backgrounds
1. `sceneWillResignActive` fires — app is about to lose focus
2. `sceneDidEnterBackground` fires — app is now in background
3. iOS grants a brief window (~5-30 seconds) for cleanup via `beginBackgroundTask`
4. After the background task expires, the app is suspended
5. All TCP sockets are closed by the OS during suspension
6. The app's process remains in memory but receives no CPU time
7. iOS may terminate the app entirely under memory pressure

### 2.2 What Cannot Work on iOS
- **Persistent TCP connections in background** — iOS will close them
- **VPN-style network extensions for SSH** — requires Network Extension entitlement, complex, Apple review concerns
- **Background fetch/refresh** — not designed for persistent connections, unpredictable scheduling
- **VOIP push tricks** — Apple has cracked down on non-VOIP apps using this entitlement; App Store rejection risk

### 2.3 What the Background Task Window Allows
- Send SSH disconnect message gracefully
- Save terminal display state (scrollback snapshot)
- Save connection metadata for reconnection
- Persist any unsaved user data

## 3. How Existing Apps Handle This

### 3.1 Blink Shell
- Accepts disconnect on background
- Uses Mosh (UDP-based) as primary transport to mitigate TCP issues
- For SSH, reconnects on foreground with tmux reattach
- Premium feature: "Always On" via a managed VPN profile (complex setup)

### 3.2 Termius
- Accepts disconnect on background
- Reconnects automatically on foreground
- tmux/screen reattach for session persistence
- Shows reconnection status inline

### 3.3 La Terminal
- Accepts disconnect on background
- Fast reconnect on foreground
- Suggests tmux for session persistence
- No background persistence tricks

### 3.4 Prompt (Panic)
- Accepts disconnect on background
- Clean reconnect flow
- Status banner shows connection state on return

## 4. Decision

**Accept disconnect on background. Optimize for fast reconnect + tmux reattach.**

This is the App Store-safe, reliable approach used by every major iOS SSH client.

## 5. Connection State Model

```
┌──────────┐     user taps     ┌────────────┐   SSH handshake   ┌───────────┐
│   Idle   │ ───────────────>  │ Connecting │ ───────────────>  │ Connected │
└──────────┘                   └────────────┘                   └───────────┘
                                     │                               │
                                     │ timeout/                      │ app backgrounds /
                                     │ failure                       │ network lost /
                                     ▼                               │ server disconnect
                                ┌──────────┐                         │
                                │  Failed  │ <───────────────────────┘
                                └──────────┘
                                     │
                                     │ user taps reconnect /
                                     │ auto-reconnect on foreground
                                     ▼
                                ┌────────────┐
                                │Reconnecting│ ──> Connected or Failed
                                └────────────┘
```

### 5.1 States
| State | Description |
|---|---|
| Idle | No active connection attempt |
| Connecting | SSH handshake in progress (bounded timeout) |
| Connected | SSH session active, terminal usable |
| Failed | Connection lost or attempt failed, reason displayed |
| Reconnecting | Attempting to restore a previous connection |

### 5.2 Transitions
- **Idle → Connecting**: User taps connect on a saved connection
- **Connecting → Connected**: SSH handshake + auth succeeds
- **Connecting → Failed**: Timeout, auth failure, network unreachable, host key rejection
- **Connected → Failed**: App backgrounded (TCP dies), network change, server-side disconnect
- **Failed → Reconnecting**: Auto-reconnect on foreground return, or user taps reconnect
- **Reconnecting → Connected**: Handshake + auth succeeds
- **Reconnecting → Failed**: Reconnect attempt fails (show message, offer retry)

## 6. Backgrounding Sequence

### 6.1 App Enters Background
1. `sceneWillResignActive` fires
2. App calls `beginBackgroundTask` to get cleanup window
3. Save terminal scrollback snapshot (for display restoration)
4. Save connection identity (host, port, username, auth method) for reconnect
5. Send SSH disconnect message to server (graceful close)
6. Transition connection state to Failed with reason "App suspended"
7. Call `endBackgroundTask`

### 6.2 App Returns to Foreground
1. `sceneWillEnterForeground` fires
2. Restore terminal display from saved snapshot (immediate visual continuity)
3. Check network availability via `NWPathMonitor`
4. If network available: begin auto-reconnect
5. Show inline status banner: "Reconnecting..."
6. On success: transition to Connected, banner changes to "Reconnected"
7. If previous session used tmux: auto-reattach to tmux session (see Phase 12)
8. On failure: show "Connection lost" banner with "Reconnect" button
9. Terminal display remains visible (from snapshot) throughout reconnect attempt

### 6.3 Network Change While Foregrounded
1. `NWPathMonitor` detects path change (WiFi → cellular, network loss)
2. If connection drops: transition to Failed
3. Show inline status banner
4. If new network available: attempt auto-reconnect after brief delay (1-2 seconds)
5. If no network: show "No network connection" with monitoring for restoration

## 7. Terminal Display Preservation
During disconnect/reconnect, the terminal view should not go blank. Strategy:
1. Before disconnect: capture current terminal surface content as a display snapshot
2. On foreground return: immediately render the snapshot in the terminal view
3. On reconnect success: libghostty resumes live rendering (snapshot is replaced)
4. On tmux reattach: tmux redraws the screen, replacing the snapshot naturally

This ensures the user sees their last terminal state immediately, even before reconnection completes.

## 8. What This Strategy Does NOT Do
- Does NOT keep SSH alive in background (impossible on iOS without VPN tricks)
- Does NOT use Mosh (UDP transport is a non-goal for v1)
- Does NOT guarantee zero interruption (all iOS SSH clients have this limitation)
- Does NOT persist running commands through background (commands in flight are lost)

## 9. Referenced By
- [Phase 10: iOS Lifecycle & Reconnection](../specs/L-10-ios-lifecycle-reconnection.md)
- [Phase 12: tmux Reconnect & Reattach](../specs/L-12-tmux-reconnect-reattach.md)
- [Phase 13: Reliability Hardening](../specs/L-13-reliability-hardening.md)
