#!/usr/bin/env bash
#
# Symlink this repo's skills into ~/.claude/skills/ so edits here are live
# immediately in Claude Code -- no copy/redeploy step, single source of truth.
#
# Portable by design: the link target is THIS repo's absolute path, discovered
# at runtime, so it works from any clone location on any machine. Nothing about
# your paths is baked into the repo.
#
# Idempotent -- safe to run repeatedly. Refreshes existing symlinks; NEVER
# clobbers a real directory/file (those are skipped with a warning).
#
# Target dir override: set CLAUDE_CONFIG_DIR (defaults to ~/.claude).
#
# Usage:  ./skills/link-into-claude.sh
#
set -euo pipefail

SKILLS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"

mkdir -p "$CLAUDE_SKILLS"

linked=0 skipped=0
for path in "$SKILLS_SRC"/*/; do
  name="$(basename "$path")"                     # basename strips trailing slash
  src="$SKILLS_SRC/$name"                        # clean target, no trailing slash
  [[ -f "$src/SKILL.md" ]] || continue          # only real skills
  dest="$CLAUDE_SKILLS/$name"

  if [[ -L "$dest" ]]; then
    ln -sfn "$src" "$dest"                       # refresh existing symlink
    echo "  linked   $name"
    linked=$((linked + 1))
  elif [[ -e "$dest" ]]; then
    echo "  SKIP     $name -- real path exists at $dest (not a symlink); remove it to link" >&2
    skipped=$((skipped + 1))
  else
    ln -s "$src" "$dest"
    echo "  linked   $name"
    linked=$((linked + 1))
  fi
done

echo "done: $linked linked, $skipped skipped  ->  $CLAUDE_SKILLS"
