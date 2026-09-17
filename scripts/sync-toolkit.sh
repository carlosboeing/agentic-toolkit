#!/usr/bin/env bash
#
# sync-toolkit — unified harness and git hook synchronization
#
# Synchronizes the agentic toolkit across both user harnesses ($HOME)
# and local project repositories (~/Projects/carlos/*).
#
# Usage:
#   ./scripts/sync-toolkit.sh              interactive wizard (if TTY) or full sync (if non-interactive)
#   ./scripts/sync-toolkit.sh --all        full sync: harnesses (~/) + repositories (~/Projects/carlos/)
#   ./scripts/sync-toolkit.sh --harness    sync only harness tools in $HOME (skills, hooks, plugins)
#   ./scripts/sync-toolkit.sh --repos      sync only git hooks across project repositories
#   ./scripts/sync-toolkit.sh --dry-run    audit mode: report drift without modifying files
#   ./scripts/sync-toolkit.sh --adopt      fold a real spoke directory into the hub
#   ./scripts/sync-toolkit.sh -y|--yes     automated: non-interactive full sync
#   ./scripts/sync-toolkit.sh [path]       target a single specific repository
#   ./scripts/sync-toolkit.sh -h|--help    show this synopsis
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"
HUB="${HUB:-$HOME/.claude/skills}"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects/carlos}"

# External skill sources
CROSSREV_SKILLS="${CROSSREV_SKILLS:-$PROJECTS_DIR/crossrev/skills}"
COPYDESK_SKILLS="${COPYDESK_SKILLS:-$PROJECTS_DIR/copydesk/skills}"

# Canonical hook sources
HOUSEKEEP_SRC="$REPO_ROOT/git-hooks/drift-guard/housekeep"
PRE_PUSH_SRC="$REPO_ROOT/git-hooks/drift-guard/pre-push"
POST_MERGE_SRC="$REPO_ROOT/git-hooks/drift-guard/post-merge"
PRE_COMMIT_SRC="$REPO_ROOT/git-hooks/private-workbench-guard/pre-commit"

# Canonical lifecycle hook sources
MERMAID_HOOK_SRC="$REPO_ROOT/hooks/validate-mermaid/validate-mermaid.sh"
OPENCODE_MERMAID_SRC="$REPO_ROOT/hooks/validate-mermaid/opencode-validate-mermaid.ts"

# Default repositories in local project fleet
DEFAULT_REPO_NAMES=("claude-code-resources" "crossrev" "copydesk" "penmark" "quotacap")

# Spokes that point at the hub
SPOKES=(
  "$HOME/.agents/skills"
  "$HOME/.gemini/config/skills"
)

# Colors
if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
  C_BOLD="\033[1m"
  C_GREEN="\033[32m"
  C_YELLOW="\033[33m"
  C_CYAN="\033[36m"
  C_BLUE="\033[34m"
  C_DIM="\033[2m"
  C_RESET="\033[0m"
else
  C_BOLD=""
  C_GREEN=""
  C_YELLOW=""
  C_CYAN=""
  C_BLUE=""
  C_DIM=""
  C_RESET=""
fi

# Counters
TOTAL_HARNESS_UPDATED=0
TOTAL_REPO_HOOKS_UPDATED=0
TOTAL_REPOS_CHECKED=0

MODE="all"
DRY_RUN=0
ADOPT=0
ASSUME_YES=0
TARGET_PATH=""
ORIG_ARG_COUNT=$#

print_usage() {
  sed -n '3,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "   ${C_DIM}would:${C_RESET} $*"
  else
    "$@"
  fi
}

# ----------------------------------------------------------- CLI Parsing ---

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"
      shift
      ;;
    --harness)
      MODE="harness"
      shift
      ;;
    --repos)
      MODE="repos"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --adopt)
      ADOPT=1
      shift
      ;;
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    -*)
      echo "unknown flag: $1" >&2
      print_usage >&2
      exit 2
      ;;
    *)
      if [[ -z "$TARGET_PATH" ]]; then
        TARGET_PATH="$1"
        MODE="repos"
        shift
      else
        echo "unexpected extra argument: $1" >&2
        exit 2
      fi
      ;;
  esac
done

# ---------------------------------------------------- Interactive Wizard ---

run_wizard() {
  echo -e "${C_BOLD}${C_BLUE}sync-toolkit — agentic toolkit installer & synchronization wizard${C_RESET}\n"

  # [1/3] Detect Installed AI Harnesses
  echo -e "${C_BOLD}${C_CYAN}=== [1/3] Detecting Installed AI Harnesses ===${C_RESET}"
  
  if [[ -d "$HOME/.claude" ]]; then
    printf "  %-40s %b[DETECTED]%b\n" "Claude Code (~/.claude)" "$C_GREEN" "$C_RESET"
  else
    printf "  %-40s %b[NOT DETECTED]%b\n" "Claude Code (~/.claude)" "$C_DIM" "$C_RESET"
  fi

  if [[ -d "$HOME/.agents" || -d "$HOME/.codex" ]]; then
    printf "  %-40s %b[DETECTED]%b\n" "Codex CLI (~/.agents, ~/.codex)" "$C_GREEN" "$C_RESET"
  else
    printf "  %-40s %b[NOT DETECTED]%b\n" "Codex CLI (~/.agents, ~/.codex)" "$C_DIM" "$C_RESET"
  fi

  if [[ -d "$HOME/.gemini/antigravity-cli" || -d "$HOME/.gemini" ]]; then
    printf "  %-40s %b[DETECTED]%b\n" "Antigravity (~/.gemini/antigravity-cli)" "$C_GREEN" "$C_RESET"
  else
    printf "  %-40s %b[NOT DETECTED]%b\n" "Antigravity (~/.gemini/antigravity-cli)" "$C_DIM" "$C_RESET"
  fi

  if [[ -d "$HOME/.agents" || -d "$HOME/.kimi-code" ]]; then
    printf "  %-40s %b[DETECTED]%b\n" "Kimi Code (~/.agents)" "$C_GREEN" "$C_RESET"
  else
    printf "  %-40s %b[NOT DETECTED]%b\n" "Kimi Code (~/.agents)" "$C_DIM" "$C_RESET"
  fi

  if [[ -d "$HOME/.config/opencode" ]]; then
    printf "  %-40s %b[DETECTED]%b\n" "OpenCode (~/.config/opencode)" "$C_GREEN" "$C_RESET"
  else
    printf "  %-40s %b[NOT DETECTED]%b\n" "OpenCode (~/.config/opencode)" "$C_DIM" "$C_RESET"
  fi

  if [[ -d "$HOME/.grok" || -d "$HOME/.claude" ]]; then
    printf "  %-40s %b[DETECTED via Claude compat]%b\n" "Grok Build TUI (~/.grok)" "$C_GREEN" "$C_RESET"
  else
    printf "  %-40s %b[NOT DETECTED]%b\n" "Grok Build TUI (~/.grok)" "$C_DIM" "$C_RESET"
  fi

  echo ""
  # [2/3] Global Harness Tools ($HOME)
  echo -e "${C_BOLD}${C_CYAN}=== [2/3] Global Harness Tools (\$HOME) ===${C_RESET}"
  local skill_count
  skill_count="$(find "$SKILLS_SRC" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  printf "  • %-45s %b[READY]%b\n" "$skill_count Authored Skills (hub ~/.claude/skills & spokes)" "$C_GREEN" "$C_RESET"
  printf "  • %-45s %b[READY]%b\n" "Claude Code Lifecycle Hooks (validate-mermaid.sh)" "$C_GREEN" "$C_RESET"
  printf "  • %-45s %b[READY]%b\n" "OpenCode Command Wrappers & Mermaid Plugin" "$C_GREEN" "$C_RESET"

  echo ""
  # [3/3] Local Project Repositories
  echo -e "${C_BOLD}${C_CYAN}=== [3/3] Local Project Repositories (~/Projects/carlos/) ===${C_RESET}"
  for rname in "${DEFAULT_REPO_NAMES[@]}"; do
    local rpath="$PROJECTS_DIR/$rname"
    if [[ -d "$rpath/.git" || -f "$rpath/.git" ]]; then
      local sidecar_note=""
      [[ -d "$rpath/.workbench/.git" ]] && sidecar_note=" (+ .workbench sidecar)"
      printf "  • %-45s %b[TARGET]%b\n" "$rname$sidecar_note" "$C_BLUE" "$C_RESET"
    fi
  done

  echo ""
  local reply=""
  if [[ -r /dev/tty ]]; then
    read -r -p "Synchronize all detected harnesses and repository targets? [Y/n] " reply </dev/tty || reply="y"
  else
    read -r -p "Synchronize all detected harnesses and repository targets? [Y/n] " reply || reply="y"
  fi

  case "${reply:-y}" in
    y|Y|yes|YES)
      MODE="all"
      ;;
    n|N|no|NO)
      echo ""
      echo "Select synchronization scope:"
      echo "  1) Harness environment only (\$HOME)"
      echo "  2) Project repositories only (~/Projects/carlos/)"
      echo "  3) Cancel"
      local choice=""
      if [[ -r /dev/tty ]]; then
        read -r -p "Enter choice [1-3]: " choice </dev/tty || choice="3"
      else
        read -r -p "Enter choice [1-3]: " choice || choice="3"
      fi
      case "$choice" in
        1) MODE="harness" ;;
        2) MODE="repos" ;;
        *) echo "Aborted."; exit 0 ;;
      esac
      ;;
    *)
      MODE="all"
      ;;
  esac
  echo ""
}

# Check if interactive wizard should run
if [[ $ORIG_ARG_COUNT -eq 0 && -t 0 && -t 1 && $ASSUME_YES -eq 0 ]]; then
  run_wizard
fi

# ---------------------------------------------------- Tier 1: Harness ---

sync_authored() {
  local copied=0
  local -a sources=("$SKILLS_SRC"/*/)
  local bundle_skills
  run mkdir -p "$HUB"

  for bundle_skills in "$REPO_ROOT"/tools/*/skills/; do
    [[ -d "$bundle_skills" ]] || continue
    sources+=("$bundle_skills"/*/)
  done

  if [[ -d "$CROSSREV_SKILLS" ]]; then
    sources+=("$CROSSREV_SKILLS"/*/)
  else
    echo -e "   ${C_DIM}note: no CrossRev checkout at $CROSSREV_SKILLS; skipping pr-review/pr-resolve${C_RESET}"
  fi

  if [[ -d "$COPYDESK_SKILLS" ]]; then
    sources+=("$COPYDESK_SKILLS"/*/)
  else
    echo -e "   ${C_DIM}note: no CopyDesk checkout at $COPYDESK_SKILLS; skipping copydesk${C_RESET}"
  fi

  for path in "${sources[@]}"; do
    local name src dest
    [[ -d "$path" ]] || continue
    src="${path%/}"
    name="$(basename "$src")"
    [[ -f "$src/SKILL.md" ]] || continue
    dest="$HUB/$name"

    if [[ -L "$dest" ]]; then
      echo "   unlinking legacy symlink in hub: $name"
      run rm "$dest"
    fi

    # Check for drift before copying
    if [[ ! -d "$dest" ]] || ! diff -r -q -x '__pycache__' "$src" "$dest" >/dev/null 2>&1; then
      run rsync -a --delete --exclude='__pycache__' "$src/" "$dest/"
      copied=$((copied + 1))
      TOTAL_HARNESS_UPDATED=$((TOTAL_HARNESS_UPDATED + 1))
    fi
  done
  echo -e "  • Authored skills -> $HUB  ($copied copied/updated)"
}

sync_spoke() {
  local dir="$1" parent
  parent="$(dirname "$dir")"
  if [[ ! -d "$parent" ]]; then
    echo -e "  • $dir  ${C_DIM}(skipped: harness parent dir not present)${C_RESET}"
    return
  fi

  if [[ -L "$dir" ]]; then
    local current
    current="$(readlink "$dir")"
    if [[ "$current" == "$HUB" ]]; then
      echo -e "  • $dir  ${C_GREEN}(ok: symlink -> hub)${C_RESET}"
    else
      echo -e "  • $dir  ${C_YELLOW}(repointing from $current -> $HUB)${C_RESET}"
      run ln -sfn "$HUB" "$dir"
      TOTAL_HARNESS_UPDATED=$((TOTAL_HARNESS_UPDATED + 1))
    fi
    return
  fi

  if [[ ! -e "$dir" ]]; then
    echo -e "  • $dir  ${C_GREEN}(creating symlink -> hub)${C_RESET}"
    run ln -s "$HUB" "$dir"
    TOTAL_HARNESS_UPDATED=$((TOTAL_HARNESS_UPDATED + 1))
    return
  fi

  # Real directory
  local strays=()
  local entry base
  for entry in "$dir"/*/; do
    [[ -d "$entry" ]] || continue
    base="$(basename "$entry")"
    [[ -e "$HUB/$base" ]] || strays+=("$base")
  done

  if [[ $ADOPT -eq 0 ]]; then
    echo -e "  • $dir  ${C_YELLOW}(REAL DIRECTORY — not touching without --adopt)${C_RESET}"
    if [[ ${#strays[@]} -gt 0 ]]; then
      echo "     holds ${#strays[@]} skill(s) the hub does not: ${strays[*]}"
    fi
    return
  fi

  echo -e "  • $dir  ${C_GREEN}(adopting into hub)${C_RESET}"
  for base in "${strays[@]}"; do
    echo "     adopting $base into hub"
    run rsync -a --exclude='__pycache__' "$dir/$base/" "$HUB/$base/"
  done
  run rm -rf "$dir"
  run ln -s "$HUB" "$dir"
  TOTAL_HARNESS_UPDATED=$((TOTAL_HARNESS_UPDATED + 1))
}

sync_claude_hooks() {
  local claude_dir="$HOME/.claude"
  if [[ ! -d "$claude_dir" ]]; then
    echo -e "  • Claude hooks  ${C_DIM}(skipped: ~/.claude not present)${C_RESET}"
    return
  fi

  local dest_dir="$claude_dir/hooks"
  local dest="$dest_dir/validate-mermaid.sh"
  run mkdir -p "$dest_dir"

  if [[ ! -f "$MERMAID_HOOK_SRC" ]]; then
    echo -e "  • $dest  ${C_YELLOW}(skipped: source missing)${C_RESET}"
    return
  fi

  if [[ ! -f "$dest" ]]; then
    echo -e "  • Claude hook -> $dest  ${C_GREEN}[NEW]${C_RESET}"
    run cp "$MERMAID_HOOK_SRC" "$dest"
    run chmod +x "$dest"
    TOTAL_HARNESS_UPDATED=$((TOTAL_HARNESS_UPDATED + 1))
  elif ! cmp -s "$MERMAID_HOOK_SRC" "$dest"; then
    echo -e "  • Claude hook -> $dest  ${C_YELLOW}[UPDATING]${C_RESET}"
    run cp "$MERMAID_HOOK_SRC" "$dest"
    run chmod +x "$dest"
    TOTAL_HARNESS_UPDATED=$((TOTAL_HARNESS_UPDATED + 1))
  elif [[ ! -x "$dest" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo -e "  • Claude hook -> $dest  ${C_YELLOW}[CHMOD]${C_RESET} (would make executable)"
    else
      echo -e "  • Claude hook -> $dest  ${C_YELLOW}[CHMOD]${C_RESET} (making executable)"
      run chmod +x "$dest"
    fi
    TOTAL_HARNESS_UPDATED=$((TOTAL_HARNESS_UPDATED + 1))
  else
    echo -e "  • Claude hook -> $dest  ${C_GREEN}[OK]${C_RESET}"
  fi
}

sync_opencode() {
  local cfg="$HOME/.config/opencode"
  if [[ ! -d "$cfg" ]]; then
    echo -e "  • OpenCode tools  ${C_DIM}(skipped: ~/.config/opencode not present)${C_RESET}"
    return
  fi

  # Command wrappers
  local out="$cfg/command" src name dest written=0 kept=0
  run mkdir -p "$out"

  for src in "$HUB"/*/SKILL.md; do
    [[ -f "$src" ]] || continue
    name="$(basename "$(dirname "$src")")"
    dest="$out/$name.md"

    if [[ -f "$dest" ]] && ! grep -q 'skill using the skill tool' "$dest"; then
      kept=$((kept + 1))
      continue
    fi

    local content
    content=$(printf -- '---\ndescription: "invoke the %s skill"\n---\n\nInvoke the `%s` skill using the skill tool, then apply it to the request below. If no request is given, invoke the skill with no arguments.\n\n$ARGUMENTS\n' "$name" "$name")

    if [[ ! -f "$dest" ]] || [[ "$(<"$dest")" != "$content" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "   ${C_DIM}would write: $dest${C_RESET}"
      else
        printf -- '%s' "$content" > "$dest"
      fi
      written=$((written + 1))
      TOTAL_HARNESS_UPDATED=$((TOTAL_HARNESS_UPDATED + 1))
    fi
  done
  echo -e "  • OpenCode wrappers -> $out  ($written written/updated, $kept user-owned)"

  # Mermaid plugin
  local plugin_dest="$cfg/plugins/validate-mermaid.ts"
  if [[ -f "$OPENCODE_MERMAID_SRC" ]]; then
    run mkdir -p "$cfg/plugins"
    if [[ ! -f "$plugin_dest" ]] || ! cmp -s "$OPENCODE_MERMAID_SRC" "$plugin_dest"; then
      echo -e "  • OpenCode mermaid plugin -> $plugin_dest  ${C_GREEN}[UPDATING]${C_RESET}"
      run cp "$OPENCODE_MERMAID_SRC" "$plugin_dest"
      TOTAL_HARNESS_UPDATED=$((TOTAL_HARNESS_UPDATED + 1))
    else
      echo -e "  • OpenCode mermaid plugin -> $plugin_dest  ${C_GREEN}[OK]${C_RESET}"
    fi
  fi
}

verify_hub_integrity() {
  if [[ $DRY_RUN -eq 0 && -d "$HUB" ]]; then
    local bad=()
    for entry in "$HUB"/*; do
      [[ -L "$entry" ]] && bad+=("$(basename "$entry")")
    done
    if [[ ${#bad[@]} -gt 0 ]]; then
      echo -e "${C_YELLOW}WARNING: Hub contains symlinks: ${bad[*]}${C_RESET}" >&2
      return 1
    fi
  fi
  return 0
}

sync_harness() {
  echo -e "${C_BOLD}${C_CYAN}=== Tier 1: AI Harness Environment (\$HOME) ===${C_RESET}"
  sync_authored
  for s in "${SPOKES[@]}"; do
    sync_spoke "$s"
  done
  sync_claude_hooks
  sync_opencode
  verify_hub_integrity
  echo ""
}

# ---------------------------------------------------- Tier 2: Repositories ---

is_managed_privacy_guard() {
  local hook_file="$1"
  [[ -f "$hook_file" ]] && grep -q 'public-repo-plus-private-workbench' "$hook_file"
}

sync_single_repo_hook() {
  local src="$1"
  local dest="$2"
  local hook_name
  hook_name="$(basename "$dest")"

  if [[ ! -f "$src" ]]; then
    echo -e "     ${C_YELLOW}[SOURCE MISSING]${C_RESET} $hook_name"
    return
  fi

  if [[ ! -f "$dest" ]]; then
    echo -e "     ${C_GREEN}[NEW]${C_RESET} $hook_name -> $dest"
    run cp "$src" "$dest"
    run chmod +x "$dest"
    TOTAL_REPO_HOOKS_UPDATED=$((TOTAL_REPO_HOOKS_UPDATED + 1))
  elif ! cmp -s "$src" "$dest"; then
    echo -e "     ${C_YELLOW}[DRIFT]${C_RESET} $hook_name (updating canonical copy)"
    run cp "$src" "$dest"
    run chmod +x "$dest"
    TOTAL_REPO_HOOKS_UPDATED=$((TOTAL_REPO_HOOKS_UPDATED + 1))
  else
    # Already matches, ensure executable
    if [[ ! -x "$dest" ]]; then
      if [[ $DRY_RUN -eq 1 ]]; then
        echo -e "     ${C_YELLOW}[CHMOD]${C_RESET} would make $hook_name executable"
      else
        echo -e "     ${C_YELLOW}[CHMOD]${C_RESET} making $hook_name executable"
        run chmod +x "$dest"
      fi
      TOTAL_REPO_HOOKS_UPDATED=$((TOTAL_REPO_HOOKS_UPDATED + 1))
    else
      echo -e "     ${C_DIM}[OK] $hook_name${C_RESET}"
    fi
  fi
}

sync_repo_target() {
  local target="$1"
  local target_name
  target_name="$(basename "$target")"
  TOTAL_REPOS_CHECKED=$((TOTAL_REPOS_CHECKED + 1))

  echo -e "  • ${C_BOLD}$target${C_RESET}"

  local githooks_dir="$target/scripts/githooks"
  run mkdir -p "$githooks_dir"

  # Sync housekeep, pre-push, post-merge
  sync_single_repo_hook "$HOUSEKEEP_SRC" "$githooks_dir/housekeep"
  sync_single_repo_hook "$PRE_PUSH_SRC" "$githooks_dir/pre-push"
  sync_single_repo_hook "$POST_MERGE_SRC" "$githooks_dir/post-merge"

  # Sync pre-commit only if repo uses .workbench
  if [[ -d "$target/.workbench" ]]; then
    local pc_dest="$githooks_dir/pre-commit"
    if [[ ! -f "$pc_dest" ]] || is_managed_privacy_guard "$pc_dest"; then
      sync_single_repo_hook "$PRE_COMMIT_SRC" "$pc_dest"
    else
      echo -e "     ${C_YELLOW}[PRESERVED]${C_RESET} custom pre-commit hook (not toolkit-managed; leaving untouched)"
    fi
  elif [[ -f "$githooks_dir/pre-commit" ]]; then
    if ! is_managed_privacy_guard "$githooks_dir/pre-commit"; then
      echo -e "     ${C_DIM}[PRESERVED] custom pre-commit hook${C_RESET}"
    fi
  fi

  # Audit and configure core.hooksPath
  local current_hooks
  current_hooks="$(git -C "$target" config core.hooksPath 2>/dev/null || true)"
  if [[ "$current_hooks" != "scripts/githooks" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo -e "     ${C_YELLOW}[HOOKS PATH DRIFT]${C_RESET} core.hooksPath is '${current_hooks:-unset}'; would set to scripts/githooks"
    else
      run git -C "$target" config core.hooksPath scripts/githooks
      echo -e "     ${C_GREEN}[CONFIGURED]${C_RESET} core.hooksPath = scripts/githooks"
    fi
  else
    echo -e "     ${C_DIM}[OK] core.hooksPath = scripts/githooks${C_RESET}"
  fi
}

sync_repos() {
  echo -e "${C_BOLD}${C_CYAN}=== Tier 2: Local Project Repositories ===${C_RESET}"
  local targets=()

  if [[ -n "$TARGET_PATH" ]]; then
    if [[ ! -d "$TARGET_PATH" ]]; then
      echo "error: specified repository path does not exist: $TARGET_PATH" >&2
      exit 1
    fi
    local repo_root
    if ! repo_root="$(git -C "$TARGET_PATH" rev-parse --show-toplevel 2>/dev/null)"; then
      echo "error: specified path is not a git repository: $TARGET_PATH" >&2
      exit 1
    fi
    targets+=("$repo_root")
  else
    for rname in "${DEFAULT_REPO_NAMES[@]}"; do
      local rpath="$PROJECTS_DIR/$rname"
      if [[ -d "$rpath" && (-d "$rpath/.git" || -f "$rpath/.git") ]]; then
        targets+=("$rpath")
      fi
    done
  fi

  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "  (no project repositories found to sync)"
    echo ""
    return
  fi

  # Expand sidecars
  local all_targets=()
  for t in "${targets[@]}"; do
    all_targets+=("$t")
    if [[ "$(basename "$t")" != ".workbench" && (-d "$t/.workbench/.git" || -f "$t/.workbench/.git") ]]; then
      all_targets+=("$t/.workbench")
    fi
  done

  for t in "${all_targets[@]}"; do
    sync_repo_target "$t"
  done
  echo ""
}

# --------------------------------------------------------------- Main ---

[[ $DRY_RUN -eq 1 ]] && echo -e "${C_YELLOW}(dry run — reporting drift without modifying files)${C_RESET}\n"

case "$MODE" in
  all)
    sync_harness
    sync_repos
    ;;
  harness)
    sync_harness
    ;;
  repos)
    sync_repos
    ;;
esac

echo -e "${C_BOLD}${C_GREEN}Synchronization complete:${C_RESET}"
if [[ "$MODE" == "all" || "$MODE" == "harness" ]]; then
  echo "  • Harness components updated: $TOTAL_HARNESS_UPDATED"
fi
if [[ "$MODE" == "all" || "$MODE" == "repos" ]]; then
  echo "  • Repository hooks updated:   $TOTAL_REPO_HOOKS_UPDATED across $TOTAL_REPOS_CHECKED target(s)"
fi
