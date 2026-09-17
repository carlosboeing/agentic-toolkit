#!/usr/bin/env bash
# test-sync-toolkit.sh — offline assertions for sync-toolkit.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sync-toolkit.sh"
FORWARDER="$REPO_ROOT/skills/sync-skills.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

_assert() { # _assert <label> <expected-exit> <actual-exit>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
    printf '  ok   %s\n' "$1"
  else
    fail=$((fail + 1))
    printf '  FAIL %s (expected exit %s, got %s)\n' "$1" "$2" "$3"
  fi
}

_assert_file() { # _assert_file <label> <filepath>
  if [ -f "$2" ]; then
    pass=$((pass + 1))
    printf '  ok   %s\n' "$1"
  else
    fail=$((fail + 1))
    printf '  FAIL %s (file missing: %s)\n' "$1" "$2"
  fi
}

_assert_executable() { # _assert_executable <label> <filepath>
  if [ -x "$2" ]; then
    pass=$((pass + 1))
    printf '  ok   %s\n' "$1"
  else
    fail=$((fail + 1))
    printf '  FAIL %s (not executable: %s)\n' "$1" "$2"
  fi
}

_assert_symlink() { # _assert_symlink <label> <linkpath> <expected_target>
  local target
  if [ -L "$2" ]; then
    target="$(readlink "$2")"
    if [ "$target" = "$3" ]; then
      pass=$((pass + 1))
      printf '  ok   %s\n' "$1"
      return
    fi
  fi
  fail=$((fail + 1))
  printf '  FAIL %s (expected symlink %s -> %s)\n' "$1" "$2" "$3"
}

# --- 1. Help & CLI flag parsing ---
"$SCRIPT" --help >/dev/null 2>&1
_assert "sync-toolkit --help exits 0" 0 $?

"$SCRIPT" --invalid-flag >/dev/null 2>&1
_assert "sync-toolkit --invalid-flag exits 2" 2 $?

# --- 2. Tier 1: Harness Environment Sync ---
MOCK_HOME="$TMP/mock_home"
MOCK_HUB="$MOCK_HOME/.claude/skills"
MOCK_PROJECTS="$TMP/mock_projects"

mkdir -p "$MOCK_HOME/.claude"
mkdir -p "$MOCK_HOME/.agents"
mkdir -p "$MOCK_HOME/.gemini/config"
mkdir -p "$MOCK_HOME/.config/opencode"
mkdir -p "$MOCK_PROJECTS"

HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" --harness -y >/dev/null 2>&1
_assert "tier 1 (--harness) exits 0" 0 $?

_assert_symlink "spoke ~/.agents/skills links to hub" "$MOCK_HOME/.agents/skills" "$MOCK_HUB"
_assert_symlink "spoke ~/.gemini/config/skills links to hub" "$MOCK_HOME/.gemini/config/skills" "$MOCK_HUB"
_assert_executable "claude hook validate-mermaid.sh is executable" "$MOCK_HOME/.claude/hooks/validate-mermaid.sh"
_assert_file "opencode mermaid plugin exists" "$MOCK_HOME/.config/opencode/plugins/validate-mermaid.ts"

# Verify OpenCode command wrappers generated
opencode_cmd_count="$(find "$MOCK_HOME/.config/opencode/command" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$opencode_cmd_count" -gt 0 ]; then
  pass=$((pass + 1))
  printf '  ok   opencode command wrappers generated (%s found)\n' "$opencode_cmd_count"
else
  fail=$((fail + 1))
  printf '  FAIL opencode command wrappers not generated\n'
fi

# Verify hub has no symlinks inside it
symlink_count="$(find "$MOCK_HUB" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')"
_assert "hub contains zero internal symlinks" 0 "$symlink_count"

# --- 3. Tier 1: Permission repair on matching hook content ---
chmod -x "$MOCK_HOME/.claude/hooks/validate-mermaid.sh"

dry_perm_out="$(HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" "$SCRIPT" --harness --dry-run)"
if [ ! -x "$MOCK_HOME/.claude/hooks/validate-mermaid.sh" ]; then
  pass=$((pass + 1))
  printf '  ok   --dry-run leaves non-executable hook untouched\n'
else
  fail=$((fail + 1))
  printf '  FAIL --dry-run unexpectedly modified permissions\n'
fi
if echo "$dry_perm_out" | grep -q "CHMOD"; then
  pass=$((pass + 1))
  printf '  ok   --dry-run reports hook permission drift\n'
else
  fail=$((fail + 1))
  printf '  FAIL --dry-run did not report hook permission drift\n'
fi

HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" --harness -y >/dev/null 2>&1
_assert_executable "live sync repairs non-executable hook when content matches" "$MOCK_HOME/.claude/hooks/validate-mermaid.sh"

# --- 4. Tier 1: Spoke Adoption ---
# Create a real directory in a spoke with an un-synced skill
rm -rf "$MOCK_HOME/.agents/skills"
mkdir -p "$MOCK_HOME/.agents/skills/custom-vendor-skill"
cat > "$MOCK_HOME/.agents/skills/custom-vendor-skill/SKILL.md" <<'EOF'
---
name: custom-vendor-skill
description: vendor test
---
vendor skill content
EOF

HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" --harness -y >/dev/null 2>&1
# Without --adopt, real directory should be preserved and not converted
if [ -d "$MOCK_HOME/.agents/skills" ] && [ ! -L "$MOCK_HOME/.agents/skills" ]; then
  pass=$((pass + 1))
  printf '  ok   real spoke directory untouched without --adopt\n'
else
  fail=$((fail + 1))
  printf '  FAIL real spoke directory unexpectedly modified without --adopt\n'
fi

HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" --harness --adopt -y >/dev/null 2>&1
_assert "spoke adoption with --adopt exits 0" 0 $?
_assert_symlink "spoke re-linked to hub after adopt" "$MOCK_HOME/.agents/skills" "$MOCK_HUB"
_assert_file "adopted skill exists in hub" "$MOCK_HUB/custom-vendor-skill/SKILL.md"

# --- 5. Tier 2: Project Repositories Sync ---
REPO1="$MOCK_PROJECTS/claude-code-resources"
REPO2="$MOCK_PROJECTS/crossrev"

git init -q -b main "$REPO1"
git -C "$REPO1" commit -q --allow-empty -m "init"

git init -q -b main "$REPO2"
git -C "$REPO2" commit -q --allow-empty -m "init"
# Add .workbench sidecar to REPO2
mkdir -p "$REPO2/.workbench"
git init -q -b main "$REPO2/.workbench"
git -C "$REPO2/.workbench" commit -q --allow-empty -m "init sidecar"

HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" --repos -y >/dev/null 2>&1
_assert "tier 2 (--repos) exits 0" 0 $?

# Verify hooks in REPO1
_assert_executable "repo1 housekeep is executable" "$REPO1/scripts/githooks/housekeep"
_assert_executable "repo1 pre-push is executable" "$REPO1/scripts/githooks/pre-push"
_assert_executable "repo1 post-merge is executable" "$REPO1/scripts/githooks/post-merge"

# Verify hooks in REPO2 and sidecar
_assert_executable "repo2 housekeep is executable" "$REPO2/scripts/githooks/housekeep"
_assert_executable "repo2 pre-commit is executable (uses .workbench)" "$REPO2/scripts/githooks/pre-commit"
_assert_executable "repo2 sidecar housekeep is executable" "$REPO2/.workbench/scripts/githooks/housekeep"

# Sidecar must not receive privacy-guard pre-commit
if [ ! -f "$REPO2/.workbench/scripts/githooks/pre-commit" ]; then
  pass=$((pass + 1))
  printf '  ok   sidecar target does not receive privacy-guard pre-commit\n'
else
  fail=$((fail + 1))
  printf '  FAIL sidecar target received privacy-guard pre-commit\n'
fi

# Verify core.hooksPath configured
repo1_hooks="$(git -C "$REPO1" config core.hooksPath)"
repo2_hooks="$(git -C "$REPO2" config core.hooksPath)"
repo2_sidecar_hooks="$(git -C "$REPO2/.workbench" config core.hooksPath)"

[ "$repo1_hooks" = "scripts/githooks" ]; _assert "repo1 core.hooksPath configured" 0 $?
[ "$repo2_hooks" = "scripts/githooks" ]; _assert "repo2 core.hooksPath configured" 0 $?
[ "$repo2_sidecar_hooks" = "scripts/githooks" ]; _assert "repo2 sidecar core.hooksPath configured" 0 $?

# --- 6. Positional repository target & Subdirectory root resolution ---
REPO3="$TMP/isolated-repo"
git init -q -b main "$REPO3"
git -C "$REPO3" commit -q --allow-empty -m "init"

# Non-git directory target must fail
NOT_A_REPO="$TMP/not-a-repo"
mkdir -p "$NOT_A_REPO"
HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" "$NOT_A_REPO" -y >/dev/null 2>&1
_assert "non-git directory target rejected with exit 1" 1 $?

# Subdirectory target must resolve to repo root, not install hooks in subdir
mkdir -p "$REPO3/nested/sub/dir"
HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" "$REPO3/nested/sub/dir" -y >/dev/null 2>&1
_assert "subdirectory target exits 0" 0 $?
_assert_executable "hooks installed at worktree root" "$REPO3/scripts/githooks/housekeep"
if [ ! -d "$REPO3/nested/sub/dir/scripts" ]; then
  pass=$((pass + 1))
  printf '  ok   subdirectory does not receive misplaced scripts/githooks\n'
else
  fail=$((fail + 1))
  printf '  FAIL subdirectory received misplaced scripts/githooks\n'
fi
repo3_hooks="$(git -C "$REPO3" config core.hooksPath)"
[ "$repo3_hooks" = "scripts/githooks" ]; _assert "core.hooksPath points to root scripts/githooks" 0 $?

# --- 7. Custom pre-commit preservation ---
# Repo without .workbench: custom pre-commit must be preserved
echo "#!/bin/sh" > "$REPO1/scripts/githooks/pre-commit"
echo "echo custom-validator" >> "$REPO1/scripts/githooks/pre-commit"
chmod +x "$REPO1/scripts/githooks/pre-commit"

HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" "$REPO1" -y >/dev/null 2>&1
if grep -q "custom-validator" "$REPO1/scripts/githooks/pre-commit"; then
  pass=$((pass + 1))
  printf '  ok   custom pre-commit preserved in repo without sidecar\n'
else
  fail=$((fail + 1))
  printf '  FAIL custom pre-commit was overwritten in repo without sidecar\n'
fi

# Repo WITH .workbench: custom pre-commit must ALSO be preserved (not overwritten by privacy-guard)
REPO4="$TMP/custom-wb-repo"
git init -q -b main "$REPO4"
git -C "$REPO4" commit -q --allow-empty -m "init"
mkdir -p "$REPO4/.workbench"
git init -q -b main "$REPO4/.workbench"
git -C "$REPO4/.workbench" commit -q --allow-empty -m "init"
mkdir -p "$REPO4/scripts/githooks"
echo "#!/bin/sh" > "$REPO4/scripts/githooks/pre-commit"
echo "echo custom-linter-hook" >> "$REPO4/scripts/githooks/pre-commit"
chmod +x "$REPO4/scripts/githooks/pre-commit"

HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" "$REPO4" -y >/dev/null 2>&1
if grep -q "custom-linter-hook" "$REPO4/scripts/githooks/pre-commit"; then
  pass=$((pass + 1))
  printf '  ok   custom pre-commit preserved in repo with sidecar\n'
else
  fail=$((fail + 1))
  printf '  FAIL custom pre-commit was overwritten in repo with sidecar\n'
fi

# Sidecar target with custom pre-commit: preserved
mkdir -p "$REPO2/.workbench/scripts/githooks"
echo "#!/bin/sh" > "$REPO2/.workbench/scripts/githooks/pre-commit"
echo "echo sidecar-custom-hook" >> "$REPO2/.workbench/scripts/githooks/pre-commit"
chmod +x "$REPO2/.workbench/scripts/githooks/pre-commit"

HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" "$REPO2/.workbench" -y >/dev/null 2>&1
if grep -q "sidecar-custom-hook" "$REPO2/.workbench/scripts/githooks/pre-commit"; then
  pass=$((pass + 1))
  printf '  ok   custom pre-commit preserved in sidecar target\n'
else
  fail=$((fail + 1))
  printf '  FAIL custom pre-commit was overwritten in sidecar target\n'
fi

# --- 8. --dry-run audit mode ---
# Tamper with repo3's hook
echo "# modified" > "$REPO3/scripts/githooks/housekeep"
HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$SCRIPT" "$REPO3" --dry-run >/dev/null 2>&1
_assert "--dry-run exits 0" 0 $?
if grep -q "# modified" "$REPO3/scripts/githooks/housekeep"; then
  pass=$((pass + 1))
  printf '  ok   --dry-run leaves drifted file intact\n'
else
  fail=$((fail + 1))
  printf '  FAIL --dry-run modified drifted file\n'
fi

# --- 9. Idempotence ---
output1="$(HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" "$SCRIPT" --all -y)"
output2="$(HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" "$SCRIPT" --all -y)"
_assert "idempotent run exits 0" 0 $?

if echo "$output2" | grep -q "Harness components updated: 0" && echo "$output2" | grep -q "Repository hooks updated:   0"; then
  pass=$((pass + 1))
  printf '  ok   idempotent run reports 0 updates on second pass\n'
else
  fail=$((fail + 1))
  printf '  FAIL idempotent run reported unexpected updates\n'
fi

# --- 10. Non-interactive execution with closed stdin ---
( HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" "$SCRIPT" --all < /dev/null ) >/dev/null 2>&1
_assert "execution with closed stdin terminates cleanly (exit 0)" 0 $?

# --- 11. Forwarder skills/sync-skills.sh ---
HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" \
  "$FORWARDER" --dry-run >/dev/null 2>&1
_assert "skills/sync-skills.sh forwarder exits 0" 0 $?

echo ""
printf '%d passed, %d failed\n' "$pass" "$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
