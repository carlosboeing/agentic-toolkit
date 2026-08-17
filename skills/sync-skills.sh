#!/usr/bin/env bash
#
# Sync this repo's AUTHORED skills into the skill hub, and keep every other
# harness pointed at it.
#
# TOPOLOGY (see docs/2-design/2026-08-06-skill-installation-topology-design.md):
#
#   claude-code-resources/skills/            --copy-->  ~/.claude/skills  (the HUB)
#   claude-code-resources/tools/*/skills/    --copy-->  ~/.claude/skills
#   crossrev/skills/                         --copy-->  ~/.claude/skills
#                                                   ^
#                                    whole-dir symlink from each SPOKE:
#                                      ~/.agents/skills          (Codex, Kimi Code)
#                                      ~/.gemini/config/skills   (Antigravity)
#
# NOT a spoke: Grok Build TUI reads the hub through Claude compat
# (compat.claude.skills = true). Do not add ~/.grok/skills — Grok
# already scans ~/.claude/skills, and a spoke would list every skill twice.
#
# Tool bundles use a `tools/*/skills/*/` glob because their names are open-ended.
# CrossRev remains an explicit external source. A bundle glob must never be
# expected to find it, or its two skills would stop syncing without a warning.
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
REPO_ROOT="$(cd "$SKILLS_SRC/.." && pwd)"
HUB="$HOME/.claude/skills"

# CrossRev lives in its own repository now, outside the bundle glob. Override
# the path if the checkout is somewhere else.
CROSSREV_SKILLS="${CROSSREV_SKILLS:-$HOME/Projects/carlos/crossrev/skills}"

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
  local -a sources=("$SKILLS_SRC"/*/)
  local bundle_skills
  mkdir -p "$HUB"

  # Three sources. Standalone skills live beside this script. Extraction-ready
  # tool bundles carry their skills under tools/<name>/skills/. CrossRev's two
  # ship with the tool in its own repository, because they travel with it.
  # CrossRev reproduces its skill text at runtime and needs no install, but both
  # are still invokable by hand in an ordinary session, so both belong in the hub.
  #
  # An unmatched bundle glob stays literal, hence the -d guard. This preserves
  # the old explicit CrossRev source while letting every real tools/ bundle join
  # the same copy loop.
  for bundle_skills in "$REPO_ROOT"/tools/*/skills/; do
    [[ -d "$bundle_skills" ]] || continue
    sources+=("$bundle_skills"/*/)
  done

  #
  # A missing checkout says so rather than skipping quietly. Silence is exactly
  # what made the old glob a bad mechanism, and a warning here costs nothing on a
  # machine that legitimately has no CrossRev.
  if [[ -d "$CROSSREV_SKILLS" ]]; then
    sources+=("$CROSSREV_SKILLS"/*/)
  else
    echo "-- note: no CrossRev checkout at $CROSSREV_SKILLS"
    echo "     pr-review and pr-resolve will not be synced. Clone"
    echo "     carlosboeing/crossrev, or set CROSSREV_SKILLS to its skills/ dir."
  fi

  # An unmatched glob stays literal, hence the -d guard.
  for path in "${sources[@]}"; do
    local name src dest
    [[ -d "$path" ]] || continue
    src="${path%/}"
    name="$(basename "$src")"
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
