# Progress

## L-00: Project Bootstrap & App Shell

**Status:** done
**Started:** 2026-02-17
**Completed:** 2026-02-17

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Create project.yml and generate Xcode project | done | 066b787 | |
| S2 | Verify deployment target and project settings | done | cdce195 | |
| S3 | Build tab view with Connections and Settings tabs | done | 8acb829 | |
| S4 | Add empty state view with CTA and placeholder sheet | done | 624a72a | |
| S5 | Add placeholder Settings content | done | b339c51 | |
| S6 | Add VoiceOver labels to all interactive elements | done | 2a00a3f | |
| S7 | Add unit smoke test for app launch | done | 0ab1c04 | |
| S8 | Run simulator verification and UAT checklist | done | 5d5f0c2 | |

**Decisions:** (none)
**Blockers:** (none)

## L-01: Connection Data Model & CRUD

**Status:** done
**Started:** 2026-02-17
**Completed:** 2026-02-17

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Define Connection model with all fields | done | 41791c0 | |
| S2 | Set up SwiftData persistence layer | done | 8392351 | |
| S3 | Build connection list view with empty state | done | 5000afa | |
| S4 | Build add/edit connection form with validation | done | 08faafc | |
| S5 | Implement save, update, and delete operations | done | 7e0655e | |
| S6 | Add auth method selector (UI only) | done | a910d6e | |
| S7 | Add VoiceOver labels to all interactive elements | done | 53f7af9 | |
| S8 | Run UAT verification and relaunch test | done | fa1b895 | |

**Decisions:** (none)
**Blockers:** (none)

## L-02: Docker Test Harness

**Status:** done
**Started:** 2026-02-18
**Completed:** 2026-02-18

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Create Dockerfile with OpenSSH, tmux, bash, and test user | done | c233fb7 | |
| S2 | Create docker-compose.yml with port mapping and health check | done | 66365dc | |
| S3 | Create start-harness.sh and stop-harness.sh scripts | done | 0987386 | |
| S4 | Verify harness connectivity | done | 15369ba | |
| S5 | Write test-harness README | done | 3b40611 | |

**Decisions:** (none)
**Blockers:** (none)

## L-03: SSH Connect & Password Auth

**Status:** in-progress
**Started:** 2026-02-18
**Completed:**

| Step | Description | Status | Commit | Notes |
|------|-------------|--------|--------|-------|
| S1 | Add Citadel SPM dependency | done | de7a3db | |
| S2 | Create SSH connection service wrapping Citadel client | done | f868568 | |
| S3 | Implement connection state machine with bounded timeout | done | 38e472a | |
| S4 | Add connect action from connection list | done | 870be1c | |
| S5 | Build SSHSessionView (connected-state placeholder) | done | fde9429 | |
| S6 | Implement password prompt flow | done | 4f752bd | |
| S7 | Add disconnect action | done | fde9429 | Included in S5 commit |
| S8 | Implement Keychain password storage with biometric access control | done | | |
| S9 | Add "Save password?" prompt after successful auth | done | | Included in S5 commit |
| S10 | Map SSH errors to human-readable messages | done | | |
| S11 | Add VoiceOver labels for all states and actions | done | | Included in S5 commit |
| S12 | Write integration tests against Docker harness | done | | |
| S13 | Execute UAT checklist | pending | | |

**Decisions:** Steps S7, S9, S11 were implemented inline within S5's SSHSessionView and subview files rather than as separate commits, since the view code was written holistically.
**Blockers:** (none)
