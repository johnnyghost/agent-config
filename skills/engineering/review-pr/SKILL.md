---
name: review-pr
description: Peer-review a teammate's checked-out branch as a thorough reviewer. Use when the user has someone else's PR or branch checked out locally and asks to "review this PR", "review this diff", "do a code review", or "check this branch before I approve". Runs `git diff <base>...HEAD` and surfaces six classes of issue — API/interface design, logic bugs in new code, missing edge cases & error paths, security concerns, regressions to existing behavior, and architecture/coupling problems. Explicitly ignores code style, performance, naming nits, missing tests, missing docs, and bikeshed-able preferences. Produces a severity-tagged markdown report (must-fix / consider / question) grouped by file plus a mechanical verdict (request-changes / comment / approve). Do NOT use for self-review of the user's own changes — use react-doctor or a self-review skill instead.
license: MIT
metadata:
  author: joaohenriques
  version: "0.1.0"
---

# review-pr

Two-pass peer review of a teammate's checked-out branch. Surfaces design and correctness issues; explicitly ignores style, naming, and bikesheds so the report stays high-signal.

## When to use

- User has a teammate's PR or branch checked out locally and asks to review it.
- User says "review this PR", "review this diff", "do a code review", "check this branch before I approve".
- User wants a written reviewer's pass before submitting GitHub feedback.

## When NOT to use

- User is reviewing their **own** changes — use `react-doctor` or a self-review skill instead.
- User wants a style/format/lint pass — that's the linter's job.
- User wants a dedicated security audit — this skill flags **obvious** security issues but is not a security review.
- User wants a performance investigation — out of scope; use a perf-focused skill.
- No branch is checked out (only a PR URL) — ask the user to `gh pr checkout <n>` first, or hand off to a different skill that operates on remote PRs.

## Instructions

Follow these steps in order. Do not skip steps. Do not reorder them.

### 1. Detect the base branch

- If the user named a base branch, use it.
- Otherwise: try `git rev-parse --verify main` then `git rev-parse --verify master`. Use whichever exists.
- If neither exists, ask the user for the base branch name. Do not guess.
- Sanity-check: `git rev-parse --abbrev-ref HEAD` must NOT equal the base. If it does, stop and ask the user to check out the PR branch.

### 2. Gather the diff

- `git diff <base>...HEAD --stat` — file overview.
- `git diff <base>...HEAD` — full diff.
- If the diff is larger than ~2000 lines, stop and ask the user whether to focus on specific files before continuing.

### 3. Gather context (capped at 20 files outside the diff)

- For each modified **exported** symbol (functions, classes, types, constants), search for callers/usages with `rg`. Open the call sites to assess regressions and design fit.
- Read sibling files in modified directories when needed to assess architectural fit (is this in the right layer, does it respect existing boundaries?).
- **Hard cap: do not open more than 20 files outside the diff.** If you find yourself wanting more context, surface the uncertainty as a `question` finding instead of digging further.

### 4. Two-pass review

Perform two passes per file. Do not interleave them — design first, correctness second.

**Pass A — Design lens.** For each modified file, ask:

- **API / interface / signature.** Is the type accurate? Is the abstraction at the right level? Are parameters clean (no leaky implementation details, no boolean traps, no `any`)? Does the return shape compose with how it's used?
- **Architecture / coupling.** Is the logic in the right module/layer? Are dependencies pointing the right way? Does the change respect existing module boundaries?

**Pass B — Correctness lens.** For each modified file, ask:

- **Logic bugs in new code.** Off-by-ones, wrong conditionals, inverted booleans, broken invariants, bad assumptions about inputs.
- **Missing edge cases / unhandled error paths.** Nulls, empty arrays, async failures, network errors, concurrent calls, partial state.
- **Security.** Auth checks, input validation, data exposure, injection, secrets in code. Flag **obvious** issues only — this is not a security audit.
- **Regressions.** For each modified exported symbol, check the callers found in step 3. Does the new behavior still satisfy them? Is any caller now broken or relying on removed behavior?

### 5. Filter findings against the anti-list

Before tagging, drop any finding that falls into these categories. They are out of scope for this skill:

- Code style or formatting.
- Performance (unless egregious — e.g., O(n²) on a hot path or an obvious N+1).
- Variable naming nits, **unless** the name actively misleads.
- Missing tests.
- Missing comments or docstrings, **unless** their absence hides a non-obvious invariant.
- Bikeshed-able preferences (single vs double quote, `function` vs arrow, etc.).
- Hypothetical bugs that aren't reachable from any code path the diff actually touches.

If you catch yourself writing one of these, delete the finding.

### 6. Tag every surviving finding

Each finding gets exactly one tag:

- **must-fix** — bug, design flaw, regression, or security issue that should block the PR. **MUST** include a concrete suggested fix (a code change, not a vague direction).
- **consider** — design or correctness concern worth surfacing but debatable. Observation only — no suggested fix. The PR author decides.
- **question** — something not obviously wrong; you want the author to clarify intent. Phrase as a question.

Be conservative with `must-fix`. If you can't write a concrete fix, it's a `consider` or `question`.

### 7. Compute the verdict mechanically

Apply this rule. Do not override it:

- Any finding tagged **must-fix** → verdict is **request-changes**.
- Else any finding tagged **consider** or **question** → verdict is **comment**.
- Else (no findings at all) → verdict is **approve**.

### 8. Produce the report

Output as markdown in chat. Use this exact structure:

```markdown
## Review: <branch> → <base>

<one-line summary: file count, line count, headline takeaway>

### <relative/path/to/file.ts>

- **must-fix** [`L42`] — <issue description>
  - **Fix:** <concrete suggested change>
- **consider** [`L78`] — <observation>
- **question** [`L120`] — <clarifying question>

### <next file>

...

### Verdict: <request-changes | comment | approve>

<one-sentence justification tying the verdict back to the findings>
```

Group findings by file. Within a file, sort by line number ascending. If a finding spans multiple lines, use the start line.

If there are no findings at all, the report is just a one-line summary and the `approve` verdict.

## Example

**User:** "review this branch, base is main"

**Agent:**

1. Confirms HEAD is `feature/session-validation`, base is `main`.
2. `git diff main...HEAD --stat`: 4 files, 87 lines added.
3. `git diff main...HEAD`: full diff, fits in context.
4. `src/auth/session.ts` exports new `validateSession`. Greps callers: 3 sites in `src/api/`. Opens those files (3 of 20 budget used).
5. Design pass: `validateSession` returns `boolean | null` — leaky tri-state. Callers all treat falsy as "invalid", losing the distinction.
6. Correctness pass: empty-token branch isn't handled in `validateSession`, would throw on `""`. One caller's middleware order changed — now rate-limit runs before auth, which may be intentional but is worth questioning.
7. Filter: nothing in the anti-list.
8. Tag and report:

```markdown
## Review: feature/session-validation → main

4 files, 87 lines. Two correctness issues in session validation; one architectural question about middleware order.

### src/auth/session.ts

- **must-fix** [`L34`] — `validateSession` returns `boolean | null`, but every caller treats falsy as "invalid". The `null` vs `false` distinction is invisible to callers and will rot.
  - **Fix:** Return `boolean`. Move the "session not found" signal into a separate `findSession()` call upstream, or throw a typed error.
- **must-fix** [`L51`] — Empty-string token isn't handled; `jwt.verify("")` throws and the catch block re-throws as `AuthError(undefined)`, losing context.
  - **Fix:** Add `if (!token) return false;` before the `jwt.verify` call.

### src/api/users.ts

- **question** [`L12`] — Middleware order changed: rate-limit now runs before `validateSession`. Was this intentional? Unauthenticated rate limiting is fine for public endpoints but unusual for `/users`.

### Verdict: request-changes

Two must-fix correctness bugs in `validateSession`; the middleware question can be resolved in review.
```
