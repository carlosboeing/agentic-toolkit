#!/usr/bin/env bash
#
# Sync this repo's AUTHORED skills into every installed harness's skill
# directory, as symlinks pointing straight at the repo. One source of truth,
# edits are live immediately, zero copy drift across harnesses.
#
# This automates the manual `ln -sfn` fan-out documented in
# guides/guide-harness-plugin-parity.md. It is INDEPENDENT of the `find-skills`
# tool: `~/.agents/skills/` is just the shared cross-harness skills directory
# (Codex and other agents read it) that find-skills happens to also use. This
# script only creates symlinks and never touches find-skills' lockfile or its
# installed skills.
#
# Portable: the link target is THIS clone's absolute path, discovered at
# runtime. Idempotent -- safe to run repeatedly. Never clobbers a real
# directory (a non-symlink skill is skipped with a warning). Skips harnesses
# that aren't installed.
#
# Add/remove target harnesses by editing TARGETS below.
#
# Usage:  ./skills/sync-skills.sh
#
set -euo pipefail

SKILLS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Harness skill directories. Each is used only if its parent exists (i.e. the
# harness is installed). Entries link straight to the repo.
TARGETS=(
  "$HOME/.claude/skills"          # Claude Code
  "$HOME/.agents/skills"          # Codex + any cross-harness agent
  "$HOME/.gemini/config/skills"   # Antigravity (agy)
)

sync_into() {
  local dir="$1" parent
  parent="$(dirname "$dir")"
  if [[ ! -d "$parent" ]]; then
    echo "-- $dir  (skipped: harness not installed)"
    return
  fi
  mkdir -p "$dir"

  local linked=0 skipped=0
  for path in "$SKILLS_SRC"/*/; do
    local name src dest
    name="$(basename "$path")"
    src="$SKILLS_SRC/$name"
    [[ -f "$src/SKILL.md" ]] || continue          # only real skills
    dest="$dir/$name"

    if [[ -L "$dest" ]]; then
      ln -sfn "$src" "$dest"                       # refresh existing symlink
      linked=$((linked + 1))
    elif [[ -e "$dest" ]]; then
      echo "   SKIP $name (real path, not a symlink)"
      skipped=$((skipped + 1))
    else
      ln -s "$src" "$dest"
      linked=$((linked + 1))
    fi
  done
  echo "-- $dir  ($linked linked, $skipped skipped)"
}

for t in "${TARGETS[@]}"; do
  sync_into "$t"
done
echo "done."
