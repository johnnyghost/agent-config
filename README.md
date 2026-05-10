# agent-config

> Portable, version-controlled **agent skills** (and eventually rules, hooks, and workflows) for **Cursor** and **Claude Code** — one place to define how assistants should behave on recurring tasks, then symlink that behavior into each tool.

If you have ever duplicated the same long prompt or checklist across projects, this repo is the opposite: small, focused **skill** folders with frontmatter agents use to decide *when* to follow *which* instructions. You edit markdown in git; `install.sh` wires the skills into `~/.cursor/skills`, `~/.claude/skills`, or a directory you choose.

**Roadmap:** skills today; rules, hooks, and subagents tomorrow.

## What you get

| Piece | Role |
|--------|------|
| [`skills/`](./skills/) | Source-of-truth skill trees grouped by domain (`engineering`, `writing`, `meta`, `personal`). Each skill is a folder with `SKILL.md` and optional helpers. |
| [`install.sh`](./install.sh) | Idempotent symlinks from the repo into your agent skills dirs — safe to re-run after `git pull`. |
| [`TEMPLATE.md`](./TEMPLATE.md) | Copy-paste starting point for new skills (frontmatter schema + structure). |

Skills are **flat to the tools**: domain folders are only for humans in the repo; installers expose a single namespace per skill name.

## Skills in this repo (examples)

| Skill | Domain | Summary |
|--------|--------|---------|
| [review-pr](./skills/engineering/review-pr/SKILL.md) | engineering | Peer review of someone else's checked-out branch — structured severity report, not style nits. |
| [pre-ship-review](./skills/engineering/pre-ship-review/SKILL.md) | engineering | Self-review and pre-ship checklist on *your* diff before you open or merge a PR. |

More domains have placeholders for future skills; see [`skills/README.md`](./skills/README.md) for the full domain list and layout.

## Getting started

Clone the repo, run `./install.sh`, and your existing Cursor and/or Claude skills directories (when present) get symlinks to every skill here. Overrides, dry runs, and a **single shared hub** layout are documented in **[skills/README.md](./skills/README.md)** — including how to add a skill and naming conventions.

## License

MIT — see [LICENSE](./LICENSE).
