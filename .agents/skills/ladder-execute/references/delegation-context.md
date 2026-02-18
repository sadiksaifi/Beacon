# Sub-Agent Delegation Context Template

How to package context for a sub-agent when delegating a step via the Task tool.

## Prompt Template

Use this structure when constructing the sub-agent prompt. **Inline all content directly** — the sub-agent cannot read your conversation history.

```
You are implementing step S<N> of phase L-<N> for the "<project name>" project.

## Project Context

Tech stack: <from OVERVIEW.md>
Product requirements: <from spec section 3>
Phase objective: <from spec section 1>

## Completed Steps

<For each completed step, summarize in 1-2 lines:>
- S1: <title> — <what was delivered, key files touched>
- S2: <title> — <what was delivered, key files touched>

## Decisions / Deviations

<From progress.md Decisions section, or "(none)">

## Current Step: S<N> — <title>

Complexity: <small|medium|large>

### Deliverable
<Paste the full Deliverable text from the spec>

### Details
<Paste the full Details text from the spec>

### Acceptance Criteria
<Paste the full Acceptance list from the spec>

## Key File Contents

<For each file the sub-agent will need to read or modify, paste the relevant
sections inline. Don't paste entire large files — paste the specific functions,
classes, or sections the step touches.>

### <file-path>
```
<relevant code section>
```

## Constraints

- Implement ONLY this step's deliverable. Do not touch files outside the step's scope.
- Verify ALL acceptance criteria by running commands and confirming output.
- Do NOT create git commits — the orchestrator commits after verification.
- Do NOT modify `.ladder/` files (specs, progress, overview).
- If you encounter an issue that blocks completion, report it clearly in your response rather than working around it silently.

## Expected Response

When done, report:
1. **What was implemented** — files created/modified and what changed
2. **Acceptance criteria results** — for each criterion, the command run and its output
3. **Issues encountered** — any problems, deviations, or concerns (or "none")
```

## Constraints Explained

| Constraint | Why |
|-----------|-----|
| No commits | The orchestrator verifies independently then commits with proper format |
| No `.ladder/` modifications | Progress tracking is the orchestrator's responsibility |
| Scope limited to step | Prevents unplanned side effects that break later steps |
| Report issues, don't hide them | The orchestrator can make informed decisions about deviations |

## Example: Complete Sub-Agent Prompt

```
You are implementing step S3 of phase L-2 for the "Acme Dashboard" project.

## Project Context

Tech stack: TypeScript, React 19, Hono, Drizzle ORM, SQLite
Product requirements: Users can view and filter dashboard metrics by date range
Phase objective: Build the metrics API and connect it to the frontend

## Completed Steps

- S1: Define metrics schema — created `src/db/schema/metrics.ts` with `metrics` table (id, name, value, timestamp)
- S2: Seed test data — added `src/db/seed-metrics.ts`, 500 rows of realistic test data

## Decisions / Deviations

(none)

## Current Step: S3 — Metrics API endpoint

Complexity: medium

### Deliverable
GET `/api/metrics` endpoint with date range filtering and pagination.

### Details
- Add route in `src/routes/metrics.ts`
- Accept query params: `from` (ISO date), `to` (ISO date), `page` (int, default 1), `limit` (int, default 50)
- Return JSON: `{ data: Metric[], total: number, page: number, limit: number }`
- Use Drizzle query builder with `between` for date filtering

### Acceptance Criteria
- GET /api/metrics returns 200 with seeded data
- GET /api/metrics?from=2025-01-01&to=2025-01-31 returns only January data
- GET /api/metrics?page=2&limit=10 returns correct offset
- Invalid date params return 400 with error message

## Key File Contents

### src/db/schema/metrics.ts
export const metrics = sqliteTable("metrics", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  name: text("name").notNull(),
  value: real("value").notNull(),
  timestamp: text("timestamp").notNull(),
});

### src/index.ts (route registration section)
import { metricsRoute } from "./routes/metrics";
// ... other routes
app.route("/api/metrics", metricsRoute);

## Constraints

- Implement ONLY this step's deliverable. Do not touch files outside the step's scope.
- Verify ALL acceptance criteria by running commands and confirming output.
- Do NOT create git commits — the orchestrator commits after verification.
- Do NOT modify `.ladder/` files (specs, progress, overview).
- If you encounter an issue that blocks completion, report it clearly in your response rather than working around it silently.

## Expected Response

When done, report:
1. **What was implemented** — files created/modified and what changed
2. **Acceptance criteria results** — for each criterion, the command run and its output
3. **Issues encountered** — any problems, deviations, or concerns (or "none")
```

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Sending only file paths | Sub-agent wastes turns reading files, may read wrong version | Inline all relevant content in the prompt |
| Vague step description | Sub-agent guesses intent, implements wrong thing | Paste full spec text verbatim |
| Missing acceptance criteria | Sub-agent can't self-verify | Always include the complete criteria list |
| No project context | Sub-agent makes wrong architectural choices | Include tech stack, conventions, completed steps |
| Omitting constraints | Sub-agent commits, edits spec, or touches unrelated files | Always include the constraints block |
| Pasting entire large files | Bloats sub-agent context unnecessarily | Paste only the relevant sections/functions |
