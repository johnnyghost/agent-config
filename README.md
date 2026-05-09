# agent-config

> 🤖 A collection of reusable agent skills, rules, and workflows for Cursor and Claude Code, organized by domain (engineering, writing, meta, personal).

Skills today; rules, hooks, and subagents tomorrow. Tool-agnostic — works with both Cursor and Claude Code via flat symlinks into `~/.agents/skills/`.

## Layout

```
agent-config/
├── README.md
├── LICENSE
├── TEMPLATE.md         # copy-this example skill
├── install.sh          # symlinks skills into ~/.agents/skills/
└── skills/
    ├── engineering/    # code, architecture, dev workflow
    ├── writing/        # PRDs, issues, docs, prose
    ├── meta/           # how-you-work skills (grill-me, find-skills, ...)
    └── personal/       # life stuff (finance, journaling, health, ...)
```

The folders under `skills/` are **domains** — purely organizational. Tools never see the domain layer; `install.sh` flattens it.

## How it works

Skills live in this repo at `skills/<domain>/<skill-name>/SKILL.md`.

`install.sh` creates symlinks so every skill ends up at `~/.agents/skills/<skill-name>/`, regardless of domain. From there, your existing `~/.claude/skills/` and `~/.cursor/skills/` symlinks pick them up automatically.

```
agent-config/skills/engineering/foo/SKILL.md
        ↓ install.sh
~/.agents/skills/foo  →  ../../Projects/personal/agent-config/skills/engineering/foo
        ↓ existing setup
~/.claude/skills/foo  →  ../../.agents/skills/foo
~/.cursor/skills/foo  →  ../../.agents/skills/foo
```

## Install

```sh
git clone https://github.com/<you>/agent-config.git ~/Projects/personal/agent-config
cd ~/Projects/personal/agent-config
./install.sh
```

Re-run `./install.sh` after `git pull` to pick up new skills. It's idempotent.

## Adding a skill

1. Pick a domain (`engineering`, `writing`, `meta`, `personal`).
2. Copy `TEMPLATE.md` to `skills/<domain>/<skill-name>/SKILL.md`.
3. Edit the frontmatter and body.
4. Run `./install.sh`.

Skill names must be unique across all domains — `install.sh` will fail loudly on collisions, because tools see them flat.

## Conventions

- One folder per skill: `skills/<domain>/<skill-name>/SKILL.md`.
- Frontmatter follows the schema in `TEMPLATE.md` (`name`, `description`, `license`, `metadata.author`, `metadata.version`).
- `description` should clearly state when the skill triggers — agents use it to decide whether to invoke the skill.
- Keep skills self-contained. Supporting files (scripts, references) live alongside `SKILL.md` in the same folder.

## License

MIT — see [LICENSE](./LICENSE).
