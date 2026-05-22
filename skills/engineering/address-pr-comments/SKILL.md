---
name: address-pr-comments
description: >-
  Addresses unresolved review feedback on the user's own pull request: triage
  threads, implement fixes, commit, push, reply, and resolve. Use when the user
  says `/address-pr-comments`, "fix my PR comments", "address review feedback",
  "respond to PR review", "fix Copilot/Bugbot comments on my PR", or similar.
  Defaults to the PR for the current branch; accepts a PR number or URL override.
  Validates bot/tool comments before fixing. Does not resolve merge conflicts or
  babysit CI — hand off to `babysit` when CI fails after push. Do not use for
  someone else's PR — use `review-pr` to review, not fix.
license: MIT
metadata:
  author: joaohenriques
  version: "0.1.0"
disable-model-invocation: true
---

# address-pr-comments

Triage and fix **unresolved review threads** on **your** PR: code changes, one commit per thread, push, thread replies, resolve when done. High blast radius — explicit invocation only.

## When to use

- User says **`/address-pr-comments`** or any of: "fix my PR comments", "address review feedback", "respond to PR review", "fix Copilot comments", "address Bugbot on my PR".
- Review feedback landed and the user wants threads cleared without manually clicking through GitHub.

## When NOT to use

- **Someone else's PR** — use `review-pr` (review only) or ask them to fix it.
- **Merge conflicts or branch sync** — out of scope; resolve conflicts first, then re-run.
- **CI babysitting loop** — after push, if checks fail, hand off to `babysit`.
- **Pre-ship self-review before opening a PR** — use `pre-ship-review`.

## Instructions

Follow in order. Do not skip steps.

### 1. Resolve the target PR

1. If the user gave a **PR number** or **URL**, use it.
2. Otherwise run `gh pr view` on the **current branch** to resolve the PR.
3. If no PR exists, stop and tell the user to open one or pass a number/URL.
4. Fetch PR metadata with `gh pr view <n> --json number,url,author,headRefName,baseRefName,state`.
5. **Authorship gate:** compare `author.login` to the authenticated user (`gh api user --jq .login`). If they differ, **stop**. This skill only acts on PRs you authored.
6. If the PR is not `OPEN`, stop and report its state.

When fetching GitHub comments, read only each comment body and the minimum location/URL needed to act on it; do not dump entire JSON payloads into context.

### 2. Check out the PR branch

1. Compare current branch to `headRefName`.
2. If different, run `gh pr checkout <n>`.
3. **Dirty working tree guard:** if `git status --porcelain` is non-empty before checkout, **stop** and ask the user to commit, stash, or discard local changes. Do not force-switch.

### 3. Fetch unresolved review threads

Collect **unresolved** review feedback only:

- Use `gh api` for review threads (GraphQL `pullRequest.reviewThreads` with `isResolved: false`) or equivalent `gh` commands.
- Include **all sources**: human reviewers, Copilot, Bugbot, CodeQL bot, etc.
- **Do not skip outdated/stale threads** — interpret intent against **current** code (step 5).
- Deduplicate: one work item per thread, not per reply in the thread.

Build a numbered queue. For each item capture: thread link/ID, file path (if any), line hint (if any), author, body summary, outdated flag.

### 4. Triage each thread

Assign exactly one disposition before editing code:

| Disposition | When |
|-------------|------|
| **fix** | Clear, localized change; you can implement confidently. |
| **reply-only** | Already fixed in current code, or feedback is informational/no code change needed. |
| **ask** | Architectural, behavioral, or scope-expanding change; ambiguous intent; you disagree with a human reviewer; bot comment looks invalid or uncertain. |
| **skip** | Not actionable (resolved elsewhere, duplicate, or clearly wrong after validation). |

**Bot/tool validation (required):** for Copilot, Bugbot, CodeQL, and similar — verify the issue against current code before **fix**. Only fix when valid. When invalid or uncertain, use **skip** or **ask** and explain in the thread reply; do not blindly apply bot suggestions.

**Autonomy (human comments):** auto-**fix** obvious local issues (null checks, clear bugs, rename-if-misleading). **Ask** before architectural moves, behavior changes, or anything that expands scope beyond what the comment requests.

List **ask** and **skip** items; proceed to implement **fix** and **reply-only** items without waiting unless **ask** items block a **fix** (same code region, conflicting intent) — then pause and consult the user.

### 5. Implement fixes

For each **fix** thread, in queue order:

1. Locate the target in **current** code — line numbers from the thread may be stale; match by intent.
2. Make the **minimal** change that addresses the feedback. No drive-by refactors.
3. Run quick local validation if the project has it (step 6) before committing.
4. Commit with message: `fix(review): <short summary>` — **one commit per thread**.
5. Note the commit SHA for the thread reply.

For **reply-only** threads, verify current code satisfies the feedback before replying.

For **stale/outdated** threads: if already addressed, reply citing the commit or lines that fixed it; disposition **reply-only**, then resolve if clearly done.

### 6. Pre-push validation

Before the first push of the run (and after all commits for this run):

- Run the project's **fast** checks if discoverable: e.g. `npm run lint`, `pnpm lint`, `ruff check`, `tsc --noEmit`, `cargo check`.
- Do **not** run full test suites unless the user explicitly asked or a fix is trivially covered by a one-file unit test the project already uses.
- If validation fails, fix issues within the PR scope, amend or add commits as appropriate, then push.

### 7. Push

Push to the PR branch (`git push` / `git push -u origin HEAD` if needed). One push after all commits is fine.

### 8. Reply and resolve on GitHub

For each processed thread:

- Post a **short reply** on the thread:
  - **fix:** what changed + `Fixed in <full-sha>`.
  - **reply-only:** why no new commit was needed (already fixed / acknowledged).
  - **skip (bot):** why the suggestion was rejected, with evidence.
- **Resolve the thread** when the feedback is fully addressed and no open question remains.
- **Do NOT resolve** threads dispositioned **ask**, disputed human feedback, or any thread where you replied with uncertainty or pushback — leave those open for the reviewer.

Use `gh api` to reply and resolve threads as supported by the installed `gh` version.

### 9. Post-push CI check (no loop)

Fetch check status once: `gh pr checks <n>` or `gh pr view <n> --json statusCheckRollup`.

- If **all green** (or no checks configured), note it briefly.
- If **any failing**, **stop** — do not attempt CI fixes in this skill. Report failing check names and tell the user to run **`babysit`** or fix manually.

### 10. End-of-run report

Output markdown in chat:

```markdown
## address-pr-comments: PR #<n> — <title>

<url>

| # | Thread | Author | Status | Commit | Notes |
|---|--------|--------|--------|--------|-------|
| 1 | <file or link> | @user | fixed | abc1234 | ... |
| 2 | ... | copilot | reply-only | — | already fixed in def5678 |
| 3 | ... | @peer | needs input | — | architectural; awaiting your call |

**Summary:** <N> fixed, <N> reply-only, <N> skipped, <N> needs input.

**CI:** <green | failing — run `babysit`>
```

Keep one line per thread. Sort by queue order.

## Example

**User:** `/address-pr-comments` (on branch `feat/session-validation`, PR #42)

**Agent:**

1. `gh pr view` → PR #42, author matches, open.
2. Already on `feat/session-validation`; working tree clean.
3. Fetches 4 unresolved threads: 2 human, 1 Bugbot, 1 Copilot (1 outdated).
4. Triage: 2 **fix**, 1 **reply-only** (outdated human — fixed in prior commit), 1 **skip** (invalid Bugbot).
5. Implements 2 fixes → `fix(review): handle empty token in validateSession`, `fix(review): return boolean from validateSession`.
6. Runs `npm run lint` — passes.
7. Pushes once.
8. Replies on all 4 threads; resolves 3; leaves none open (Bugbot got a polite rejection reply + resolve; invalid suggestion documented).
9. `gh pr checks 42` → pending. Reports thread table + "CI pending — re-check or run babysit if red."

## Install

Canonical path: `skills/engineering/address-pr-comments/`. From the repo root, run `./install.sh` to symlink into `~/.cursor/skills/` and peers — see repo `README.md`.
