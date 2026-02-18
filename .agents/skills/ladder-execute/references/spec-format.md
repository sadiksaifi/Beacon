<!-- SHARED: duplicated in ladder-create, ladder-execute, ladder-refine. Keep all copies in sync. -->

# Canonical Spec Format

> Single source of truth for what makes a Ladder phase spec valid.

## Contents

- [Required Sections (1–11)](#required-sections-111)
- [Optional Section](#optional-section)
- [Step Sequence Enriched Format](#step-sequence-enriched-format)
- [Concrete Example](#concrete-example)
- [Anti-Patterns](#anti-patterns)
- [Validation Rules](#validation-rules)

## Required Sections (1–11)

### 1. Objective
One sentence: what this phase delivers and why it matters.

### 2. Entry Criteria
Numbered list of conditions that must be true before work begins.
- First phase references Baseline (or "none" for greenfield).
- Subsequent phases reference predecessor phase completion.

### 3. Scope In
Bullet list of what this phase covers.

### 4. Scope Out
Bullet list of what is explicitly deferred.

### 5. Product Requirements
Numbered functional requirements (PR-1, PR-2, …).

### 6. UX Requirements
Numbered UX requirements (UX-1, UX-2, …).

### 7. Accessibility Requirements
Numbered a11y requirements (A11Y-1, A11Y-2, …).

### 8. UAT Checklist
Checkbox list of user-acceptance tests.
```markdown
- [ ] UAT-1: description
- [ ] UAT-2: description
```

### 9. Test Allocation
Table mapping test type → scope → method:
```markdown
| Type | Scope | Method |
|------|-------|--------|
| Unit | ModelClass | XCTest |
```

### 10. Exit Criteria
Numbered list. Must include "UAT checklist items pass."

### 11. Step Sequence
Ordered implementation steps using the enriched format below.

## Optional Section

### 12. References
Links to `.ladder/refs/` documents relevant to this phase.

---

## Step Sequence Enriched Format

Every step uses a unique `S<N>` ID (sequential within the phase):

```markdown
### S<N>: <imperative action title>
- **Complexity:** small | medium | large
- **Deliverable:** what this step produces
- **Files:** expected file paths
- **Depends on:** S<N> | none
- **Details:** implementation guidance (2-3 sentences)
- **Acceptance:**
  - [ ] criterion 1
  - [ ] criterion 2
```

### Complexity Guide

| Level | Scope | Typical size |
|-------|-------|-------------|
| small | Single file, straightforward | <100 lines changed |
| medium | 2-4 files, moderate logic, some design decisions | 100-300 lines |
| large | 5+ files or complex logic, may be delegatable | 300+ lines |

---

## Concrete Example

A well-formed step from a real phase spec:

```markdown
### S3: Implement rate limiting middleware
- **Complexity:** medium
- **Deliverable:** Express middleware that enforces per-IP rate limits
- **Files:** src/middleware/rate-limiter.ts, src/middleware/rate-limiter.test.ts
- **Depends on:** S1
- **Details:** Create a sliding-window rate limiter using Redis. Default to
  100 requests per 15-minute window per IP. Return 429 with Retry-After header
  when limit exceeded. Include unit tests for window sliding, limit enforcement,
  and header generation.
- **Acceptance:**
  - [ ] Middleware returns 429 when rate limit exceeded
  - [ ] Retry-After header is set correctly
  - [ ] Rate limit resets after window expires
  - [ ] Unit tests cover sliding window, limit enforcement, and header values
```

---

## Anti-Patterns

| Anti-Pattern | Example | Fix |
|-------------|---------|-----|
| Vague title | "S1: Set up stuff" | Use imperative action: "S1: Configure database connection pool" |
| Missing acceptance criteria | Step has no `Acceptance:` section | Every step needs ≥1 testable criterion |
| Untestable acceptance | "- [ ] Code is clean" | Make it observable: "- [ ] Lint passes with zero warnings" |
| No file paths | `Files:` is empty or missing | List every file the step creates or modifies |
| Empty details | `Details:` says "Implement the feature" | Provide 2-3 sentences of implementation guidance |
| Wrong complexity | "small" for a 5-file change | Match to Complexity Guide table above |
| Missing dependencies | Step uses code from S2 but says "none" | Trace data/code dependencies and list them |
| Monolith step | One step with 8 acceptance criteria | Split into smaller steps (aim for 2-4 criteria each) |

---

## Validation Rules

These rules are checked by `/ladder-execute` before starting a phase:

1. All 11 required sections present (section 12 optional).
2. Step Sequence uses `S<N>` format with sequential IDs.
3. Every step has an **Acceptance** list with at least one criterion.
4. Entry Criteria references predecessor phase or Baseline (for first phase).
5. Exit Criteria includes "UAT checklist items pass."
