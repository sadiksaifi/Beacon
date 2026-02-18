<!-- SHARED: duplicated in ladder-init, ladder-execute. Keep all copies in sync. -->

# Progress File Format

> **Cardinal Rule:** `progress.md` is the ONLY mutable document in Ladder. Specs are immutable once written. All execution state lives here.

Living execution journal at `.ladder/progress.md`.

## Structure

```markdown
# Progress

## Baseline (pre-Ladder)
(Only for brownfield projects)
- **Captured:** YYYY-MM-DD
- **Summary:** brief description of existing state
- **Key components:**
  - path/to/dir — what it does
- **Known debt:**
  - issues to be aware of

---

## L-<N>: <title>
- **Status:** pending | in-progress | done | blocked
- **Started:** YYYY-MM-DD
- **Completed:** YYYY-MM-DD
- **Spec:** .ladder/specs/L-NN-slug.md

### Steps
| Step | Status | Commit | Notes |
|------|--------|--------|-------|
| S1: <title> | pending | - | |
| S2: <title> | done | abc1234 | |

### Decisions
- <deviations from spec, or "(none)">

### Blockers
- <issues, or "(none)">
```

## Mid-Execution Example

A phase with 5 steps — 3 completed, 1 in progress, 1 pending:

```markdown
## L-02: Add authentication system
- **Status:** in-progress
- **Started:** 2026-02-15
- **Completed:** —
- **Spec:** .ladder/specs/L-02-auth-system.md

### Steps
| Step | Status | Commit | Notes |
|------|--------|--------|-------|
| S1: Configure auth provider | done | a1b2c3d | |
| S2: Create user model | done | e4f5g6h | |
| S3: Implement login flow | done | i7j8k9l | Added remember-me checkbox per user request |
| S4: Add session middleware | in-progress | - | |
| S5: Write integration tests | pending | - | |

### Decisions
- S3: Added remember-me checkbox (user requested during review)

### Blockers
- (none)
```

## Blocked Status

Use `blocked` when a phase cannot proceed due to external dependencies or unresolved issues:

```markdown
## L-03: Payment integration
- **Status:** blocked
- **Started:** 2026-02-16
- **Completed:** —
- **Spec:** .ladder/specs/L-03-payments.md

### Blockers
- Waiting for Stripe API credentials from client
- L-02 auth system must complete first (entry criteria)
```

When the blocker resolves, change status back to `in-progress` and remove the resolved blocker entry.

## Rules

1. Phases appear in numeric order.
2. Status transitions: `pending` → `in-progress` → `done` (or `blocked` → `in-progress` when unblocked).
3. **Commit** column: 7-char short SHA after step commit, or `-` if pending.
4. **Notes** column: deviations from spec only.
5. A phase is "done" when ALL steps are done/skipped AND exit criteria pass.
6. `progress.md` is the ONLY living document — specs stay immutable.
7. OVERVIEW.md Phase Registry status is derived from `progress.md`.
