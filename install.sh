#!/usr/bin/env bash
# install.sh — symlink every skill in this repo into ~/.agents/skills/ as a flat hub.
#
# Skills live at:   <repo>/skills/<domain>/<skill-name>/SKILL.md
# After install:    ~/.agents/skills/<skill-name>  ->  <repo>/skills/<domain>/<skill-name>
#
# Names must be unique across domains (tools see ~/.agents/skills/ flat). The script
# fails loudly on collisions so duplicates are caught immediately.
#
# Portable to bash 3.2+ (the macOS system default).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DST="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"

DRY_RUN=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    -h|--help)
      cat <<EOF
Usage: ./install.sh [--dry-run] [--force]

  --dry-run   Print what would happen, change nothing.
  --force     Overwrite existing symlinks/files in the destination.

Override destination with AGENTS_SKILLS_DIR=/some/path ./install.sh
EOF
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

if [ ! -d "$SKILLS_SRC" ]; then
  echo "error: $SKILLS_SRC does not exist" >&2
  exit 1
fi

mkdir -p "$SKILLS_DST"

# Collect every skill directory: one level under skills/<domain>/<skill-name>/SKILL.md.
# We expect exactly: <repo>/skills/<domain>/<skill-name>/SKILL.md
SKILL_DIRS=()
while IFS= read -r -d '' skill_md; do
  SKILL_DIRS+=("$(dirname "$skill_md")")
done < <(find "$SKILLS_SRC" -mindepth 3 -maxdepth 3 -type f -name SKILL.md -print0)

if [ "${#SKILL_DIRS[@]}" -eq 0 ]; then
  echo "no skills found under $SKILLS_SRC"
  exit 0
fi

# Detect duplicate skill names across domains by sorting.
# Build a "name<TAB>domain/name" list, sort by name, scan for adjacent duplicates.
DUP_TMP="$(mktemp -t agent-config.XXXXXX)"
trap 'rm -f "$DUP_TMP"' EXIT

for skill_dir in "${SKILL_DIRS[@]}"; do
  name="$(basename "$skill_dir")"
  domain="$(basename "$(dirname "$skill_dir")")"
  printf '%s\t%s/%s\n' "$name" "$domain" "$name" >> "$DUP_TMP"
done

# Sort and find duplicate names (first column).
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

linked=0
skipped=0
replaced=0

for skill_dir in "${SKILL_DIRS[@]}"; do
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DST/$skill_name"

  if [ -L "$target" ]; then
    current="$(readlink "$target")"
    if [ "$current" = "$skill_dir" ]; then
      skipped=$((skipped + 1))
      continue
    fi
    if [ "$FORCE" -eq 0 ]; then
      echo "skip: $skill_name (symlink exists, points elsewhere; use --force to replace)"
      skipped=$((skipped + 1))
      continue
    fi
    [ "$DRY_RUN" -eq 1 ] || rm "$target"
    replaced=$((replaced + 1))
  elif [ -e "$target" ]; then
    if [ "$FORCE" -eq 0 ]; then
      echo "skip: $skill_name (non-symlink exists at $target; use --force to replace)"
      skipped=$((skipped + 1))
      continue
    fi
    [ "$DRY_RUN" -eq 1 ] || rm -rf "$target"
    replaced=$((replaced + 1))
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "would link: $target -> $skill_dir"
  else
    ln -s "$skill_dir" "$target"
    echo "linked: $skill_name"
  fi
  linked=$((linked + 1))
done

echo
echo "done: $linked linked, $replaced replaced, $skipped already up to date"
[ "$DRY_RUN" -eq 1 ] && echo "(dry run — no changes made)"
exit 0
