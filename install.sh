#!/usr/bin/env bash
# install.sh — symlink every skill in this repo into one or more skills directories.
#
# Skills live at:   <repo>/skills/<domain>/<skill-name>/SKILL.md
# After install:    <target>/<skill-name>  ->  <repo>/skills/<domain>/<skill-name>
#
# Default targets are auto-detected: ~/.cursor/skills and ~/.claude/skills (whichever
# of ~/.cursor or ~/.claude exists). Override with one or more --target flags.
#
# Skill names must be unique across all domains. The script fails loudly on
# collisions so duplicates are caught immediately.
#
# Portable to bash 3.2+ (the macOS system default).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"

DRY_RUN=0
FORCE=0
TARGETS=()

usage() {
  cat <<EOF
Usage: ./install.sh [--target <path>]... [--dry-run] [--force]

Symlink every skill in this repo into one or more agent skills directories.

Options:
  --target <path>  Install destination. Pass multiple times to install into
                   several targets. If omitted, defaults to ~/.cursor/skills
                   and ~/.claude/skills (whichever of ~/.cursor or ~/.claude
                   exists on this machine).
  --dry-run        Print what would happen, change nothing.
  --force          Overwrite existing symlinks/files at the target.
  -h, --help       Show this message.

Examples:
  ./install.sh
  ./install.sh --target ~/.agents/skills
  ./install.sh --target ~/.cursor/skills --target ~/.claude/skills --force
  ./install.sh --dry-run
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      [ $# -ge 2 ] || { echo "error: --target requires a path" >&2; exit 2; }
      TARGETS+=("$2")
      shift 2
      ;;
    --target=*)
      TARGETS+=("${1#--target=}")
      shift
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --force)   FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "error: unknown argument '$1'" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ ! -d "$SKILLS_SRC" ]; then
  echo "error: $SKILLS_SRC does not exist" >&2
  exit 1
fi

# Auto-detect default targets if none provided.
if [ "${#TARGETS[@]}" -eq 0 ]; then
  for parent in "$HOME/.cursor" "$HOME/.claude"; do
    if [ -d "$parent" ]; then
      TARGETS+=("$parent/skills")
    fi
  done
  if [ "${#TARGETS[@]}" -eq 0 ]; then
    cat >&2 <<EOF
error: no default install target found.

Neither ~/.cursor nor ~/.claude exists on this machine. Specify a target
explicitly with --target, e.g.:

  ./install.sh --target ~/.agents/skills
EOF
    exit 1
  fi
fi

# Collect every skill directory: <repo>/skills/<domain>/<skill-name>/SKILL.md
SKILL_DIRS=()
while IFS= read -r -d '' skill_md; do
  SKILL_DIRS+=("$(dirname "$skill_md")")
done < <(find "$SKILLS_SRC" -mindepth 3 -maxdepth 3 -type f -name SKILL.md -print0)

if [ "${#SKILL_DIRS[@]}" -eq 0 ]; then
  echo "no skills found under $SKILLS_SRC"
  exit 0
fi

# Detect duplicate skill names across domains by sorting.
DUP_TMP="$(mktemp -t agent-config.XXXXXX)"
trap 'rm -f "$DUP_TMP"' EXIT

for skill_dir in "${SKILL_DIRS[@]}"; do
  name="$(basename "$skill_dir")"
  domain="$(basename "$(dirname "$skill_dir")")"
  printf '%s\t%s/%s\n' "$name" "$domain" "$name" >> "$DUP_TMP"
done

DUPES="$(awk -F'\t' '{ print $1 }' "$DUP_TMP" | sort | uniq -d || true)"
if [ -n "$DUPES" ]; then
  echo "error: duplicate skill names found:" >&2
  while IFS= read -r dup; do
    echo "  '$dup' appears in:" >&2
    awk -F'\t' -v n="$dup" '$1 == n { print "    - " $2 }' "$DUP_TMP" >&2
  done <<< "$DUPES"
  echo "skill names must be unique across domains" >&2
  exit 1
fi

# Install into each target.
total_linked=0
total_replaced=0
total_skipped=0

for target_dir in "${TARGETS[@]}"; do
  # Expand ~ if present.
  case "$target_dir" in
    "~/"*) target_dir="$HOME/${target_dir#\~/}" ;;
    "~")   target_dir="$HOME" ;;
  esac

  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$target_dir"
  fi

  echo "→ $target_dir"

  for skill_dir in "${SKILL_DIRS[@]}"; do
    skill_name="$(basename "$skill_dir")"
    target="$target_dir/$skill_name"

    if [ -L "$target" ]; then
      current="$(readlink "$target")"
      if [ "$current" = "$skill_dir" ]; then
        echo "  = $skill_name (already linked)"
        total_skipped=$((total_skipped + 1))
        continue
      fi
      if [ "$FORCE" -eq 0 ]; then
        echo "  - $skill_name (symlink exists pointing elsewhere; use --force to replace)"
        total_skipped=$((total_skipped + 1))
        continue
      fi
      [ "$DRY_RUN" -eq 1 ] || rm "$target"
      total_replaced=$((total_replaced + 1))
    elif [ -e "$target" ]; then
      if [ "$FORCE" -eq 0 ]; then
        echo "  - $skill_name (non-symlink exists; use --force to replace)"
        total_skipped=$((total_skipped + 1))
        continue
      fi
      [ "$DRY_RUN" -eq 1 ] || rm -rf "$target"
      total_replaced=$((total_replaced + 1))
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  + $skill_name (would link)"
    else
      ln -s "$skill_dir" "$target"
      echo "  + $skill_name"
    fi
    total_linked=$((total_linked + 1))
  done
done

echo
echo "done: $total_linked linked, $total_replaced replaced, $total_skipped already up to date"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run — no changes made)"
exit 0
