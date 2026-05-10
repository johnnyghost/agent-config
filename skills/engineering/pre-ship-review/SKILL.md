---
name: pre-ship-review
description: >-
  Runs a pre-ship self-review plus a PR-style pass on the user's own changes.
  Use when the user says `/pre-ship-review`, "review my work", "pre-ship review",
  "review my diff", "before I open a PR", "self-review before push", or similar.
  Prefers a three-dot git diff against an integration branch, resolving the base
  in order: origin/main, main, origin/master, master (ask if none exist); then
  honors explicit paths; then falls back to conversation context. Produces (1) a
  short pass/fail checklist with a small fixed core plus diff-informed items,
  then (2) severity-tagged PR-style findings grouped by file. Always ignores
  formatting, style, and naming nitpicks; ignores missing tests, missing docs, and
  performance micro-optimizations by default unless the change clearly warrants
  them or the user asks. Ends with a dual verdict (PR-style plus solo shipping
  label). Do not use for reviewing a teammate's checked-out branch — use
  `review-pr` instead.
license: MIT
metadata:
  author: joaohenriques
  version: "0.1.0"
disable-model-invocation: true
---

# pre-ship-review

Pre-ship pass on **your own** work: a tight **self-review checklist** first, then a **PR-style** design and correctness review. High signal; no linter cosplay.

## When to use

- User says **`/pre-ship-review`** or any of: "review my work", "pre-ship review", "review my diff", "self-review before PR", "before I push", "sanity-check my branch".
- User finished a feature and wants a structured gate before opening a PR or pushing.

## When NOT to use

- Reviewing **someone else's** branch or PR — use `review-pr`.
- User only wants React-specific post-change checks — `react-doctor` may be lighter.
- User wants lint/format/style enforcement — use the project's formatter and linter.

## Instructions

Follow in order. Do not skip steps.

### 1. Resolve review scope (diff → paths → chat)

**A. Git repo + no explicit path-only mode from user**

1. Resolve **base ref** by testing, in order, until one succeeds with `git rev-parse --verify <ref>`: `origin/main`, `main`, `origin/master`, `master`.
2. If **none** exist, ask the user for the base ref. Do not guess beyond this list.
3. If `HEAD` equals the resolved base branch (same ref), stop and ask the user to check out their working branch, or confirm they want a range other than `HEAD`.
4. Run `git diff <base>...HEAD --stat` and `git diff <base>...HEAD`.
5. If the diff is empty, say so and ask whether to (a) review **staged** or **unstaged** changes, (b) use **explicit paths** the user names, or (c) rely on **chat-only** context — then follow that choice.
6. If the diff exceeds ~2000 lines, stop and ask which directories or files to focus on before continuing.

**B. User named explicit paths** (files or folders)

- Review those paths. If a sensible git range still exists from step A, use it for surrounding context; otherwise read the paths directly and note the scope in the report header.

**C. No repo or user declines git**

- Use conversation-supplied snippets, questions, and constraints. State limitations plainly in the report header.

### 2. Section 1 — Pre-ship checklist (pass | fail | n/a)

Output **before** Section 2. Each line must be **`pass`**, **`fail`**, or **`n/a`** with **one short evidence fragment** (command run, file:line, or reasoning).

**Fixed core (always include, in this order):**

1. **Intent vs diff** — The diff matches what I meant to ship (no accidental files, debug prints, or WIP).
2. **Risk surface** — I identified the highest-risk behavior changed (auth, money, data loss, migrations, concurrency, security boundaries) and **smoke-tested** or **reasoned through** it.
3. **Failure modes** — Error paths for new/changed flows are plausible (timeouts, empty input, permission denied, partial failure) and do not leak sensitive details.
4. **Secrets** — No secrets, tokens, or private URLs in code, fixtures, or logs added in this scope.
5. **Compatibility** — I considered rollback / backward compatibility / schema or API compatibility if the change touches persistence, wire formats, or public interfaces.
6. **Observability** — If production behavior changes materially, logs/metrics/errors remain understandable (no silent catastrophic failure modes).

**Diff-informed (add 3–7 items, not generic filler):**

- Derive from the actual diff: e.g. migration → backup/ordering/reversibility; new endpoint → authn/z and input validation; UI → a11y/keyboard; async → cancellation/races; deps → license/supply-chain only if materially changed.
- If the diff is tiny and low risk, add **fewer** items (minimum **3**) rather than padding.

If any **fixed core** line is **`fail`**, Section 2 still runs, but the verdict must reflect that shipping is unsafe until addressed.

### 3. Section 2 — PR-style review (two passes)

Perform **Pass A (design)** then **Pass B (correctness)** per modified file — same lenses as `review-pr`: API/interface, architecture/coupling, logic bugs in new code, edge cases and error paths, obvious security issues, regressions for changed exported surface.

**Context budget:** when using a git diff, follow `review-pr`'s discipline: at most **20 files outside the diff** for caller/regression context; otherwise emit **`question`** findings.

### 4. Filter findings (anti-list)

**Always drop (never report):** formatting, style, naming nitpicks, bikeshed preferences.

**Drop by default (unless clearly warranted by the diff or the user explicitly asked):** missing tests; missing docs/comments; performance micro-optimizations. **Do include** these when omitting them would likely hide a **real bug**, **operational incident**, or **breaking public contract**.

Drop hypothetical issues not reachable from code paths touched by the diff.

### 5. Tag surviving findings

Same tags and rules as `review-pr`:

- **must-fix** — concrete suggested fix required.
- **consider** — observation; no required fix.
- **question** — clarify intent.

Be conservative with **must-fix**: if you cannot state a concrete fix, downgrade to **consider** or **question**.

### 6. Dual verdict (mechanical)

1. Compute **PR-style verdict** using `review-pr` rules: any **must-fix** → **request-changes**; else any **consider** or **question** → **comment**; else **approve**.
2. Map to **solo shipping** label:
   - **approve** → **ship**
   - **comment** → **ship with notes**
   - **request-changes** → **do not ship yet**

Emit **both** on one line: `Verdict: <PR-style> (<solo>)`.

### 7. Report format (markdown)

Use this structure exactly:

```markdown
## Pre-ship review: <branch or scope> → <base or "paths" or "chat">

<one-line summary: size, headline risk>

### Checklist (pre-ship)

| Item | Status | Evidence |
|------|--------|----------|
| Intent vs diff | pass \| fail \| n/a | ... |
| ... | ... | ... |

### Findings

### <relative/path/to/file>

- **must-fix** [`L42`] — ...
  - **Fix:** ...
- **consider** [`L78`] — ...
- **question** [`L120`] — ...

### Verdict: <request-changes \| comment \| approve> (<do not ship yet \| ship with notes \| ship>)

<one sentence tying verdict to checklist and findings>
```

Sort findings by file path, then by start line. If there are **no** Section 2 findings, still include the verdict line and explain that Section 2 is clean.

## Canonical copy vs personal install

The **canonical** skill directory for this repo is `skills/engineering/pre-ship-review/`. To use it globally in Cursor, symlink it into your personal skills directory (Cursor resolves `~/.cursor/skills/<name>/`):

```bash
mkdir -p ~/.cursor/skills
ln -sf "/Users/joaohenriques/Projects/personal/agent-config/skills/engineering/pre-ship-review" ~/.cursor/skills/pre-ship-review
```

On another machine, replace the source path with the absolute path to your clone of this repository.
