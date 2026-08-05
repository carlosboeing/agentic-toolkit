#!/usr/bin/env bash
#
# Sync this repo's AUTHORED skills into the skill hub, and keep every other
# harness pointed at it.
#
# TOPOLOGY (see docs/2-design/2026-08-06-skill-installation-topology-design.md):
#
#   claude-code-resources/skills/  --copy-->  ~/.claude/skills   (the HUB)
#                                                   ^
#                                    whole-dir symlink from each SPOKE:
#                                      ~/.agents/skills          (Codex, Kimi Code)
#                                      ~/.gemini/config/skills   (Antigravity)
#
# The hub holds real directories only, so Claude Code -- the primary harness --
# never resolves a symlink to find a skill. Every other harness reaches the same
# content through its spoke, so there is exactly one copy on disk and drift is
# structurally impossible.
#
# This replaces the previous symlink fan-out, which pointed all three harness
# directories straight at this repo. Authored skills are now COPIED into the
# hub, so an edit here is not live until this script runs.
#
# Idempotent -- safe to run repeatedly. Never deletes a real spoke directory
# without --adopt, because that directory is usually a skill some vendor CLI
# just installed.
#
# Usage:
#   ./skills/sync-skills.sh              copy authored skills, repair spokes
#   ./skills/sync-skills.sh --dry-run    print the plan, change nothing
#   ./skills/sync-skills.sh --adopt      fold a real spoke directory into the
#                                        hub, then replace it with the symlink
#
set -euo pipefail

SKILLS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB="$HOME/.claude/skills"

# Harness skill directories that point at the hub. Each is used only if its
# parent exists (i.e. the harness is installed).
#   ~/.agents/skills        Codex reads $HOME/.agents/skills per OpenAI's docs
#                           Kimi Code reads it natively
#   ~/.gemini/config/skills the only global path all three Antigravity variants
#                           recognise
# NOT a spoke: ~/.codex/skills holds Codex's own .system/ bundled skills.
SPOKES=(
  "$HOME/.agents/skills"
  "$HOME/.gemini/config/skills"
)

DRY_RUN=0
ADOPT=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --adopt)   ADOPT=1 ;;
    -h|--help) sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "   would: $*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------- authored ---
# Mirror each authored skill into the hub. --delete so a file removed from the
# source is removed from the hub, but scoped per-skill so the hub's third-party
# directories are never touched.

sync_authored() {
  local copied=0
  mkdir -p "$HUB"
  for path in "$SKILLS_SRC"/*/; do
    local name src dest
    name="$(basename "$path")"
    src="$SKILLS_SRC/$name"
    [[ -f "$src/SKILL.md" ]] || continue          # only real skills
    dest="$HUB/$name"

    if [[ -L "$dest" ]]; then
      # Legacy symlink from the old fan-out topology. Replace with a real copy.
      echo "   unlinking legacy symlink: $name"
      run rm "$dest"
    fi
    run rsync -a --delete --exclude='__pycache__' "$src/" "$dest/"
    copied=$((copied + 1))
  done
  echo "-- authored skills -> $HUB  ($copied copied)"
}

# ------------------------------------------------------------------ spokes ---
# Each spoke must be a symlink to the hub. A real directory means a vendor CLI
# recreated it (npx skills add writes to ~/.agents/skills), so its contents may
# be a freshly installed skill the hub does not have yet.

sync_spoke() {
  local dir="$1" parent
  parent="$(dirname "$dir")"
  if [[ ! -d "$parent" ]]; then
    echo "-- $dir  (skipped: harness not installed)"
    return
  fi

  if [[ -L "$dir" ]]; then
    local current
    current="$(readlink "$dir")"
    if [[ "$current" == "$HUB" ]]; then
      echo "-- $dir  (ok)"
    else
      echo "-- $dir  (repointing from $current)"
      run ln -sfn "$HUB" "$dir"
    fi
    return
  fi

  if [[ ! -e "$dir" ]]; then
    echo "-- $dir  (creating symlink)"
    run ln -s "$HUB" "$dir"
    return
  fi

  # Real directory. Only --adopt may destroy it.
  local strays=()
  local entry base
  for entry in "$dir"/*/; do
    [[ -d "$entry" ]] || continue
    base="$(basename "$entry")"
    [[ -e "$HUB/$base" ]] || strays+=("$base")
  done

  if [[ $ADOPT -eq 0 ]]; then
    echo "-- $dir  (REAL DIRECTORY -- not touching it)"
    if [[ ${#strays[@]} -gt 0 ]]; then
      echo "     holds ${#strays[@]} skill(s) the hub does not: ${strays[*]}"
    fi
    echo "     re-run with --adopt to fold it into the hub and restore the symlink"
    return
  fi

  echo "-- $dir  (adopting)"
  for base in "${strays[@]}"; do
    echo "     adopting $base into the hub"
    run rsync -a --exclude='__pycache__' "$dir/$base/" "$HUB/$base/"
  done
  run rm -rf "$dir"
  run ln -s "$HUB" "$dir"
}

# -------------------------------------------------------------------- main ---

[[ $DRY_RUN -eq 1 ]] && echo "(dry run -- nothing will change)"

sync_authored
for s in "${SPOKES[@]}"; do
  sync_spoke "$s"
done

# The hub must contain no symlinks -- that is the whole point of the topology.
if [[ $DRY_RUN -eq 0 ]]; then
  bad=()
  for entry in "$HUB"/*; do
    [[ -L "$entry" ]] && bad+=("$(basename "$entry")")
  done
  if [[ ${#bad[@]} -gt 0 ]]; then
    echo "WARNING: hub contains symlinks: ${bad[*]}" >&2
    exit 1
  fi
fi

echo "done."
