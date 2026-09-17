#!/usr/bin/env bash
# test-sync-toolkit.sh — offline assertions for sync-toolkit.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/sync-toolkit.sh"
FORWARDER="$REPO_ROOT/skills/sync-skills.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export SYNC_TOOLKIT_NO_CONFIG=1

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

_assert_eq() { # _assert_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
    printf '  ok   %s\n' "$1"
  else
    fail=$((fail + 1))
    printf '  FAIL %s (expected %s, got %s)\n' "$1" "$2" "$3"
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

_assert_eq "repo1 core.hooksPath configured" "scripts/githooks" "$repo1_hooks"
_assert_eq "repo2 core.hooksPath configured" "scripts/githooks" "$repo2_hooks"
_assert_eq "repo2 sidecar core.hooksPath configured" "scripts/githooks" "$repo2_sidecar_hooks"

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
_assert_eq "core.hooksPath points to root scripts/githooks" "scripts/githooks" "$repo3_hooks"

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
HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$MOCK_PROJECTS" "$SCRIPT" --all -y >/dev/null
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

# --- 12. Config file loading & FLEET_REPOS filtering ---
TEST_CONF="$TMP/test-custom.conf"
cat > "$TEST_CONF" <<EOF
PROJECTS_DIR="$MOCK_PROJECTS"
FLEET_REPOS=("repo-fleet-a")
IGNORE_DIRS=("ignored-repo" "temp")
EOF

FLEET_A="$MOCK_PROJECTS/repo-fleet-a"
NON_FLEET_B="$MOCK_PROJECTS/repo-discovered-b"
IGNORED_C="$MOCK_PROJECTS/ignored-repo"

mkdir -p "$FLEET_A" "$NON_FLEET_B" "$IGNORED_C"
git init -q -b main "$FLEET_A" && git -C "$FLEET_A" commit -q --allow-empty -m "init"
git init -q -b main "$NON_FLEET_B" && git -C "$NON_FLEET_B" commit -q --allow-empty -m "init"
git init -q -b main "$IGNORED_C" && git -C "$IGNORED_C" commit -q --allow-empty -m "init"

HOME="$MOCK_HOME" HUB="$MOCK_HUB" \
  "$SCRIPT" --config "$TEST_CONF" --repos -y >/dev/null 2>&1
_assert "custom config execution exits 0" 0 $?
_assert_executable "fleet repo received hooks" "$FLEET_A/scripts/githooks/housekeep"

if [ ! -d "$NON_FLEET_B/scripts/githooks" ]; then
  pass=$((pass + 1))
  printf '  ok   non-fleet repo skipped when FLEET_REPOS is configured\n'
else
  fail=$((fail + 1))
  printf '  FAIL non-fleet repo was modified when FLEET_REPOS was active\n'
fi

# --- 13. --all-repos bypasses FLEET_REPOS filter ---
HOME="$MOCK_HOME" HUB="$MOCK_HUB" \
  "$SCRIPT" --config "$TEST_CONF" --all-repos --repos -y >/dev/null 2>&1
_assert "--all-repos execution exits 0" 0 $?
_assert_executable "--all-repos synced non-fleet repo" "$NON_FLEET_B/scripts/githooks/housekeep"

# --- 14. IGNORE_DIRS skips ignored checkouts ---
if [ ! -d "$IGNORED_C/scripts/githooks" ]; then
  pass=$((pass + 1))
  printf '  ok   ignored repo directory skipped during auto-discovery\n'
else
  fail=$((fail + 1))
  printf '  FAIL ignored repo was modified\n'
fi

# --- 15. EXTRA_SKILL_SOURCES ---
EXT_SKILL_DIR="$TMP/external-skills/ext-test-skill"
mkdir -p "$EXT_SKILL_DIR"
cat > "$EXT_SKILL_DIR/SKILL.md" <<EOF
---
description: external skill test
---
external skill content
EOF

cat > "$TEST_CONF" <<EOF
PROJECTS_DIR="$MOCK_PROJECTS"
FLEET_REPOS=()
EXTRA_SKILL_SOURCES=("$TMP/external-skills")
EOF

HOME="$MOCK_HOME" HUB="$MOCK_HUB" \
  "$SCRIPT" --config "$TEST_CONF" --harness -y >/dev/null 2>&1
_assert "harness sync with EXTRA_SKILL_SOURCES exits 0" 0 $?
_assert_file "external skill installed in hub" "$MOCK_HUB/ext-test-skill/SKILL.md"

# --- 16. --no-config preserves environment target and bypasses config files (P1) ---
ENV_SANDBOX="$TMP/env-sandbox"
mkdir -p "$ENV_SANDBOX/sandbox-repo-1" "$ENV_SANDBOX/sandbox-repo-2"
git init -q -b main "$ENV_SANDBOX/sandbox-repo-1" && git -C "$ENV_SANDBOX/sandbox-repo-1" commit -q --allow-empty -m "init"
git init -q -b main "$ENV_SANDBOX/sandbox-repo-2" && git -C "$ENV_SANDBOX/sandbox-repo-2" commit -q --allow-empty -m "init"

noconf_out="$(HOME="$MOCK_HOME" HUB="$MOCK_HUB" PROJECTS_DIR="$ENV_SANDBOX" \
  "$SCRIPT" --config "$TEST_CONF" --no-config --repos --dry-run -y 2>&1)"
_assert "--no-config with environment target exits 0" 0 $?

if echo "$noconf_out" | grep -q "sandbox-repo-1" && echo "$noconf_out" | grep -q "sandbox-repo-2"; then
  pass=$((pass + 1))
  printf '  ok   --no-config scans environment PROJECTS_DIR targets\n'
else
  fail=$((fail + 1))
  printf '  FAIL --no-config did not scan environment target repos\n'
fi

if ! echo "$noconf_out" | grep -q "repo-fleet-a"; then
  pass=$((pass + 1))
  printf '  ok   --no-config bypasses config file fleet selection\n'
else
  fail=$((fail + 1))
  printf '  FAIL --no-config applied config file fleet selection\n'
fi

# --- 17. Partial local config layers over user configuration (P1) ---
# Create an isolated mock toolkit checkout so .sync.local does not touch working tree
MOCK_TOOLKIT="$TMP/mock-toolkit"
mkdir -p "$MOCK_TOOLKIT/scripts" "$MOCK_TOOLKIT/git-hooks" "$MOCK_TOOLKIT/hooks" "$MOCK_TOOLKIT/skills"
cp "$SCRIPT" "$MOCK_TOOLKIT/scripts/sync-toolkit.sh"
chmod +x "$MOCK_TOOLKIT/scripts/sync-toolkit.sh"
cp -R "$REPO_ROOT/git-hooks/"* "$MOCK_TOOLKIT/git-hooks/"
cp -R "$REPO_ROOT/hooks/"* "$MOCK_TOOLKIT/hooks/"
cp -R "$REPO_ROOT/skills/"* "$MOCK_TOOLKIT/skills/"

MOCK_XDG="$TMP/mock-xdg"
mkdir -p "$MOCK_XDG/agentic-toolkit"
MOCK_USER_SKILLS="$TMP/mock-user-skills/user-layer-skill"
mkdir -p "$MOCK_USER_SKILLS"
cat > "$MOCK_USER_SKILLS/SKILL.md" <<EOF
---
description: user layer skill test
---
user skill content
EOF

LAYER_PROJECTS="$TMP/layer-projects"
mkdir -p "$LAYER_PROJECTS/repo-user-fleet" "$LAYER_PROJECTS/repo-discovered-other"
git init -q -b main "$LAYER_PROJECTS/repo-user-fleet" && git -C "$LAYER_PROJECTS/repo-user-fleet" commit -q --allow-empty -m "init"
git init -q -b main "$LAYER_PROJECTS/repo-discovered-other" && git -C "$LAYER_PROJECTS/repo-discovered-other" commit -q --allow-empty -m "init"

# User config defines FLEET_REPOS and EXTRA_SKILL_SOURCES
cat > "$MOCK_XDG/agentic-toolkit/sync.conf" <<EOF
PROJECTS_DIR="$LAYER_PROJECTS"
FLEET_REPOS=("repo-user-fleet")
EXTRA_SKILL_SOURCES=("$TMP/mock-user-skills")
EOF

# Partial repo-local .sync.local defines ONLY IGNORE_DIRS (does NOT set FLEET_REPOS or EXTRA_SKILL_SOURCES)
cat > "$MOCK_TOOLKIT/.sync.local" <<EOF
IGNORE_DIRS=("custom-ignore-dir" "temp")
EOF

# Sourcing cascade must preserve user's FLEET_REPOS and EXTRA_SKILL_SOURCES
SYNC_TOOLKIT_NO_CONFIG="" XDG_CONFIG_HOME="$MOCK_XDG" HOME="$MOCK_HOME" HUB="$MOCK_HUB" \
  "$MOCK_TOOLKIT/scripts/sync-toolkit.sh" --repos -y >/dev/null 2>&1
_assert "layered config repos sync exits 0" 0 $?
_assert_executable "partial local config preserves user FLEET_REPOS target" "$LAYER_PROJECTS/repo-user-fleet/scripts/githooks/housekeep"

if [ ! -d "$LAYER_PROJECTS/repo-discovered-other/scripts/githooks" ]; then
  pass=$((pass + 1))
  printf '  ok   partial local config does not drop user fleet restriction to scan all repos\n'
else
  fail=$((fail + 1))
  printf '  FAIL partial local config dropped user fleet restriction\n'
fi

SYNC_TOOLKIT_NO_CONFIG="" XDG_CONFIG_HOME="$MOCK_XDG" HOME="$MOCK_HOME" HUB="$MOCK_HUB" \
  "$MOCK_TOOLKIT/scripts/sync-toolkit.sh" --harness -y >/dev/null 2>&1
_assert "layered config harness sync exits 0" 0 $?
_assert_file "partial local config preserves user EXTRA_SKILL_SOURCES" "$MOCK_HUB/user-layer-skill/SKILL.md"

# When local .sync.local explicitly sets FLEET_REPOS, it overrides user config
cat > "$MOCK_TOOLKIT/.sync.local" <<EOF
FLEET_REPOS=("repo-discovered-other")
EOF
SYNC_TOOLKIT_NO_CONFIG="" XDG_CONFIG_HOME="$MOCK_XDG" HOME="$MOCK_HOME" HUB="$MOCK_HUB" \
  "$MOCK_TOOLKIT/scripts/sync-toolkit.sh" --repos -y >/dev/null 2>&1
_assert_executable "local config overrides user FLEET_REPOS when explicitly set" "$LAYER_PROJECTS/repo-discovered-other/scripts/githooks/housekeep"

# --- 18. Config file overrides exported environment variables (P2) ---
ENV_DIR="$TMP/prec-env-dir"
CONF_DIR="$TMP/prec-conf-dir"
ENV_HUB="$TMP/prec-env-hub"
CONF_HUB="$TMP/prec-conf-hub"

mkdir -p "$ENV_DIR/env-target" "$CONF_DIR/conf-target"
git init -q -b main "$ENV_DIR/env-target" && git -C "$ENV_DIR/env-target" commit -q --allow-empty -m "init"
git init -q -b main "$CONF_DIR/conf-target" && git -C "$CONF_DIR/conf-target" commit -q --allow-empty -m "init"

PREC_CONF="$TMP/prec-override.conf"
cat > "$PREC_CONF" <<EOF
PROJECTS_DIR="$CONF_DIR"
HUB="$CONF_HUB"
EOF

# With exported PROJECTS_DIR and HUB, --config must override both environment values
prec_out="$(PROJECTS_DIR="$ENV_DIR" HUB="$ENV_HUB" HOME="$MOCK_HOME" \
  "$SCRIPT" --config "$PREC_CONF" --repos --dry-run -y 2>&1)"

if echo "$prec_out" | grep -q "conf-target"; then
  pass=$((pass + 1))
  printf '  ok   config file overrides exported PROJECTS_DIR\n'
else
  fail=$((fail + 1))
  printf '  FAIL config file did not override exported PROJECTS_DIR\n'
fi

if ! echo "$prec_out" | grep -q "env-target"; then
  pass=$((pass + 1))
  printf '  ok   exported PROJECTS_DIR ignored when config file specifies directory\n'
else
  fail=$((fail + 1))
  printf '  FAIL exported PROJECTS_DIR took precedence over config file\n'
fi

PROJECTS_DIR="$ENV_DIR" HUB="$ENV_HUB" HOME="$MOCK_HOME" \
  "$SCRIPT" --config "$PREC_CONF" --harness -y >/dev/null 2>&1
if [ -d "$CONF_HUB" ] && [ ! -d "$ENV_HUB" ]; then
  pass=$((pass + 1))
  printf '  ok   config file overrides exported HUB\n'
else
  fail=$((fail + 1))
  printf '  FAIL exported HUB took precedence over config file\n'
fi

# --- 19. CLI flag --projects-dir overrides config file and environment ---
CLI_DIR="$TMP/prec-cli-dir"
mkdir -p "$CLI_DIR/cli-target"
git init -q -b main "$CLI_DIR/cli-target" && git -C "$CLI_DIR/cli-target" commit -q --allow-empty -m "init"

cli_out="$(PROJECTS_DIR="$ENV_DIR" HOME="$MOCK_HOME" \
  "$SCRIPT" --config "$PREC_CONF" --projects-dir "$CLI_DIR" --repos --dry-run -y 2>&1)"

if echo "$cli_out" | grep -q "cli-target" && ! echo "$cli_out" | grep -q "conf-target"; then
  pass=$((pass + 1))
  printf '  ok   CLI flag --projects-dir overrides config file and environment\n'
else
  fail=$((fail + 1))
  printf '  FAIL CLI flag --projects-dir did not override config file\n'
fi


echo ""
printf '%d passed, %d failed\n' "$pass" "$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
