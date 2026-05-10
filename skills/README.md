# Skills

This folder is the source of truth for agent skills. `install.sh` at the repo root symlinks each skill into the agent skills directories on your machine.

## Domains

Skills are grouped by domain — purely organizational. Tools never see the domain layer; `install.sh` flattens it.

- **engineering** — code, architecture, dev workflow
- **writing** — PRDs, issues, docs, prose
- **meta** — skill authoring, planning, decision-making
- **personal** — life stuff (finance, journaling, health)

Each skill lives at `skills/<domain>/<skill-name>/SKILL.md`, optionally with supporting files alongside.

## Quick start

```sh
git clone https://github.com/johnnyghost/agent-config.git
cd agent-config
./install.sh
```

`install.sh` symlinks every skill into the agent skills directories that exist on your machine — `~/.cursor/skills/` and `~/.claude/skills/` by default. Re-run after `git pull` to pick up new skills; it's idempotent.

Override with one or more `--target` flags:

```sh
./install.sh --target ~/.cursor/skills          # one tool only
./install.sh --target ~/.agents/skills          # a custom hub
./install.sh --target ~/.cursor/skills --target ~/.claude/skills --force
```

Other options: `--dry-run` shows what would happen without changing anything, `--force` overwrites existing symlinks at the target.

## Adding a skill

1. Pick a domain (`engineering`, `writing`, `meta`, `personal`).
2. Copy `TEMPLATE.md` (repo root) to `skills/<domain>/<skill-name>/SKILL.md`.
3. Edit the frontmatter and body.
4. Run `./install.sh`.

Skill names must be unique across all domains — `install.sh` will fail loudly on collisions, because tools see them flat.

## Conventions

- One folder per skill: `skills/<domain>/<skill-name>/SKILL.md`.
- Frontmatter follows the schema in `TEMPLATE.md` (`name`, `description`, `license`, `metadata.author`, `metadata.version`).
- `description` is the most important field — agents match it against user intent. Be specific about when the skill should trigger.
- Keep skills self-contained. Supporting files (scripts, references, examples) live alongside `SKILL.md` in the same folder.

## Optional: single hub directory

Not required for normal use — documented in case it helps. One canonical skills directory with tool-specific dirs pointing at it so Cursor and Claude Code share the same skills:

```
~/.cursor/skills/<skill>  →  ~/.agents/skills/<skill>
~/.claude/skills/<skill>  →  ~/.agents/skills/<skill>
                                    ↑
                          ./install.sh --target ~/.agents/skills
                                    ↑
                  agent-config/skills/<domain>/<skill>/SKILL.md
```

To replicate:

```sh
mkdir -p ~/.agents/skills
ln -s ~/.agents/skills ~/.cursor/skills    # only if ~/.cursor/skills doesn't already exist
ln -s ~/.agents/skills ~/.claude/skills    # only if ~/.claude/skills doesn't already exist
./install.sh --target ~/.agents/skills
```

Trade-off: one symlink hop more, but every tool sees the same skills, and moving or removing skills is one-place work.
