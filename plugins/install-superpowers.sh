#!/usr/bin/env bash
#
# Install, upgrade, and report Superpowers across every harness in the rotation.
#
# Replaces superpowers-relink.sh. That script maintained symlinks from a canonical
# checkout into each harness's private cache, and documented in its own header that
# the harnesses' own commands clobber those symlinks. Two installs were found broken
# on 2026-08-19 and neither failure announced itself: Codex had an empty version slot
# and Antigravity sat three minor versions behind.
#
# This script drives each harness's official install path instead, and always reports
# the resolved version so drift is visible rather than silent.
#
# Usage:
#   install-superpowers.sh              report the resolved version per harness
#   install-superpowers.sh status       same as above
#   install-superpowers.sh install      install or upgrade where a CLI exists
#
# Harnesses without a plugin CLI print the exact manual step rather than being skipped.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Upstream is canonical. Every install path below points at the public repository, so no
# harness depends on a local clone being present or current. The clone is a development
# convenience used only by `dev` mode, and it is reported separately for that reason.
upstream_version() {
  git ls-remote --tags --refs "$UPSTREAM.git" 2>/dev/null \
    | sed -n 's|.*refs/tags/v\{0,1\}||p' \
    | sort -V | tail -1
}

UPSTREAM="https://github.com/obra/superpowers"
GIT_SPEC="superpowers@git+${UPSTREAM}.git"

green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }
yellow(){ printf '\033[33m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m' "$1"; }

# Read the version field from the first package.json matching a glob.
probe() {
  local pattern="$1" path
  for path in $pattern; do
    [ -f "$path" ] || continue
    sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$path" | head -1
    return 0
  done
  return 1
}

# OpenCode stores the package under a directory whose name contains slashes, so a glob
# cannot reach it. The manifest at the top of that directory is OpenCode's dependency
# shim, not Superpowers' own, so target the one under node_modules.
# The cache under ~/.cache/opencode survives removing the declaration that populated it,
# so a version there does not mean OpenCode loads Superpowers. Require the declaration
# too, the same way probe_antigravity requires skills rather than trusting a version
# file. Reporting a stale cache as current is what this whole report exists to avoid.
probe_opencode() {
  local found config
  config="$HOME/.config/opencode/opencode.json"
  grep -q "superpowers" "$config" 2>/dev/null || { echo "absent"; return; }
  # Same guard as status(): find exits nonzero when the cache directory is absent,
  # and an unguarded assignment would end the run rather than report "absent".
  found="$(find "$HOME/.cache/opencode/packages" -maxdepth 8 -path "*/node_modules/superpowers/package.json" 2>/dev/null | head -1 || true)"
  [ -n "$found" ] || { echo "absent"; return; }
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$found" | head -1
}

# Claude Code records an installPath per plugin, and it can point at a local checkout
# rather than the marketplace cache. Reading the cache when the install is a path install
# reports a version the harness is not running. Follow installPath first.
#
# Its marketplace, obra/superpowers-marketplace, also versions independently of
# obra/superpowers, so the cache directory name is a marketplace number while the package
# inside carries the plugin's own. Only the package number compares with an upstream tag.
claude_install_path() {
  local f="$HOME/.claude/plugins/installed_plugins.json"
  [ -f "$f" ] || return 1
  python3 - "$f" <<'PYEOF' 2>/dev/null
import json, sys, os
data = json.load(open(sys.argv[1]))

# Match the plugin named exactly "superpowers". A substring test also matches
# superpowers-chrome, superpowers-developing-for-claude-code, and any plugin whose
# path merely contains the marketplace name.
def is_superpowers(path):
    parts = [segment for segment in str(path).split(os.sep) if segment]
    return "superpowers" in parts[:-1] or (parts and parts[-1] == "superpowers")

def walk(node):
    if isinstance(node, dict):
        candidate = node.get("installPath")
        if isinstance(candidate, str) and is_superpowers(candidate):
            return candidate
        for value in node.values():
            found = walk(value)
            if found:
                return found
    elif isinstance(node, list):
        for value in node:
            found = walk(value)
            if found:
                return found
    return None

path = walk(data)
if path:
    print(path)
PYEOF
}

probe_claude() {
  local path
  path="$(claude_install_path || true)"
  if [ -n "$path" ] && [ -f "$path/package.json" ]; then
    probe "$path/package.json"
    return
  fi
  probe "$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers/*/package.json" || echo "absent"
}

# A version file alone does not mean a working install here, so require the skills the
# plugin exists to deliver. See install_antigravity for how the partial state arises.
probe_antigravity() {
  local dir="$HOME/.gemini/config/plugins/superpowers"
  [ -d "$dir/skills" ] || { echo "absent"; return; }
  probe "$dir/package.json" || echo "absent"
}

claude_detail() {
  local path
  path="$(claude_install_path || true)"
  if [ -n "$path" ] && [[ "$path" != "$HOME/.claude"* ]]; then
    echo "path install from $path"
  else
    echo "via obra/superpowers-marketplace, which versions separately"
  fi
}

# Drift has a direction. A harness ahead of the checkout is not the same problem as one
# behind it, and calling both "drifted" hides which way to fix it.
#
# An empty canon means the upstream tag could not be read, and there is then no direction
# to report. Comparing against a placeholder string is worse than reporting nothing:
# `sort -V` orders a word after every version number, so a current machine would read as
# six harnesses behind.
report_row() {
  local harness="$1" version="$2" detail="$3" canon="$4"
  local mark newest
  if [ -z "$version" ] || [ "$version" = "absent" ]; then
    mark="$(red "absent ")"
    version="absent"
  elif [ -z "$canon" ]; then
    mark="$(yellow "unknown")"
  elif [ "$version" = "$canon" ]; then
    mark="$(green "current")"
  else
    newest="$(printf '%s\n%s\n' "$version" "$canon" | sort -V | tail -1)"
    if [ "$newest" = "$version" ]; then
      mark="$(yellow "ahead  ")"
    else
      mark="$(red "behind ")"
    fi
  fi
  printf '  %-12s %-9s %-10s %s\n' "$harness" "$mark" "$version" "$(dim "$detail")"
}

status() {
  local canon
  # `|| true` is what keeps the fallback below reachable. Under `set -e` the exit
  # status of an assignment is the status of its command substitution, and `pipefail`
  # makes upstream_version fail whenever git ls-remote cannot reach the network. The
  # unguarded form exits here instead of reporting "Cannot reach".
  canon="$(upstream_version || true)"
  echo "Superpowers across the rotation"
  if [ -n "$canon" ]; then
    echo "  upstream     $(green "source ") $canon      $(dim "$UPSTREAM")"
  else
    # Leave canon empty rather than substituting a word for it. Every row below then
    # reports its installed version with no direction, which is what an unreachable
    # upstream actually tells us.
    echo "Cannot reach $UPSTREAM to read the latest tag. Versions are reported without a comparison." >&2
    echo "  upstream     $(yellow "unknown") unknown    $(dim "$UPSTREAM")"
  fi
  echo

  report_row claude "$(probe_claude)" \
    "$(claude_detail)" "$canon"
  report_row codex "$(probe "$HOME/.codex/plugins/cache/superpowers-dev/superpowers/*/package.json" || echo absent)" \
    "codex plugin marketplace upgrade" "$canon"
  report_row antigravity "$(probe_antigravity)" \
    "agy plugin install <repo url>" "$canon"
  report_row cursor "$(probe "$HOME/.cursor/plugins/cache/cursor-public/superpowers/*/package.json" || echo absent)" \
    "no plugin CLI — reinstall from the Cursor UI" "$canon"
  report_row kimi "$(probe "$HOME/.kimi-code/plugins/managed/superpowers/package.json" || echo absent)" \
    "TUI only: /plugins install $UPSTREAM" "$canon"
  report_row opencode "$(probe_opencode)" \
    "plugin array in ~/.config/opencode/opencode.json" "$canon"

  echo
  echo
  echo "  $(dim "grok reads Claude Code's plugin tree — it has no install of its own")"

  # Antigravity can hold two copies: a plugin under config/plugins and a leftover Gemini
  # CLI extension. Only the first is what agy plugin install writes, so name the other.
  #
  # Calling that copy stale needs a version to say so against, and an empty canon is not
  # one: the bare "$stale" != "$canon" test is true for every second copy when upstream
  # cannot be reached. Fall back to the plugin copy instead, because two Antigravity
  # copies at different versions is a disagreement this script can establish offline.
  # With neither reference available, report the version and claim nothing about it.
  local stale primary reference
  stale="$(probe "$HOME/.gemini/extensions/superpowers/package.json" || true)"
  if [ -n "$stale" ]; then
    primary="$(probe "$HOME/.gemini/config/plugins/superpowers/package.json" || true)"
    reference="${canon:-$primary}"
    if [ -z "$reference" ]; then
      echo "  $(yellow "note")  antigravity also carries $stale at ~/.gemini/extensions/superpowers, a Gemini CLI import, with no version to compare it against"
    elif [ "$stale" != "$reference" ]; then
      echo "  $(yellow "note")  antigravity also carries $stale at ~/.gemini/extensions/superpowers, a stale Gemini CLI import"
    fi
  fi
}

CLAUDE_MARKETPLACE="obra/superpowers-marketplace"
CLAUDE_PLUGIN="superpowers@superpowers-marketplace"

# Refreshing a marketplace only helps a machine that already has one. On a machine with
# neither the marketplace nor the plugin, a refresh is the wrong command and leaves
# Superpowers absent. Register what is missing first, then refresh what is present.
#
# Both state files are what the CLI itself writes, so they are read rather than the
# output of `claude plugin marketplace list`, whose columns are not a stable interface.
install_claude() {
  command -v claude >/dev/null 2>&1 || { echo "  claude: SKIP — CLI not in PATH"; return; }

  if grep -q "\"superpowers-marketplace\"[[:space:]]*:" \
      "$HOME/.claude/plugins/known_marketplaces.json" 2>/dev/null; then
    claude plugin marketplace update superpowers-marketplace >/dev/null 2>&1 \
      || { echo "  claude: marketplace refresh failed — check 'claude plugin marketplace list'"; return 1; }
    echo "  claude: marketplace refreshed"
  else
    claude plugin marketplace add "$CLAUDE_MARKETPLACE" >/dev/null 2>&1 \
      || { echo "  claude: could not add $CLAUDE_MARKETPLACE — run 'claude plugin marketplace add $CLAUDE_MARKETPLACE' to see why"; return 1; }
    echo "  claude: added marketplace $CLAUDE_MARKETPLACE"
  fi

  if grep -q "\"$CLAUDE_PLUGIN\"[[:space:]]*:" \
      "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
    echo "  claude: $CLAUDE_PLUGIN present, updated with the marketplace"
    return 0
  fi
  claude plugin install "$CLAUDE_PLUGIN" --scope user >/dev/null 2>&1 \
    || { echo "  claude: install failed — run 'claude plugin install $CLAUDE_PLUGIN' to see why"; return 1; }
  echo "  claude: installed $CLAUDE_PLUGIN"
}

install_codex() {
  command -v codex >/dev/null 2>&1 || { echo "  codex: SKIP — CLI not in PATH"; return; }
  # Check the marketplace root, not just its name. A superpowers marketplace can be
  # registered against the local clone, and upgrading that only ever returns the clone's
  # version. Re-adding from upstream replaces the source under the same name.
  local root
  root="$(codex plugin marketplace list 2>/dev/null | awk '/superpowers/ {print $2}' | head -1 || true)"
  if [ -z "$root" ] || [[ "$root" != *".codex"* ]]; then
    codex plugin marketplace add "$UPSTREAM" >/dev/null 2>&1 \
      || { echo "  codex: could not add the upstream marketplace"; return 1; }
  fi
  # Discarding these two statuses reported a stale or absent Codex as installed.
  codex plugin marketplace upgrade >/dev/null 2>&1 \
    || { echo "  codex: marketplace upgrade failed — run 'codex plugin marketplace upgrade' to see why"; return 1; }
  codex plugin add superpowers@superpowers-dev >/dev/null 2>&1 \
    || { echo "  codex: plugin add failed — run 'codex plugin add superpowers@superpowers-dev' to see why"; return 1; }
  echo "  codex: installed from upstream"
}

# agy plugin install clones into a fresh directory and fails with "file exists" when one
# is already there, so it cannot be run twice. Skip when the installed version already
# matches upstream, and clear the directory first when it does not — by uninstalling a
# working copy, and by removing a partial tree that no uninstall may know about.
#
# Upgrading here is destructive in two steps: the uninstall removes the working copy, and
# the install that follows needs the network. So read the upstream tag before touching
# anything, and stop when it is unreadable. An empty canon fails the equality test, which
# would send an installed and current Antigravity down the uninstall path — and the
# reinstall would then fail on the same unreachable network that emptied canon, leaving
# the harness with no Superpowers at all.
install_antigravity() {
  command -v agy >/dev/null 2>&1 || { echo "  antigravity: SKIP — agy not in PATH"; return; }

  local dir="$HOME/.gemini/config/plugins/superpowers"
  local installed canon partial=0
  installed="$(probe "$dir/package.json" || true)"

  # A version file can survive a partial install. agy plugin install fails part-way with
  # "mkdir .../hooks: file exists" when a directory is already there, and what it leaves
  # behind carries package.json but no skills. Treat that as not installed, because
  # reporting the version alone called a skill-less tree current.
  #
  # Track it separately from installed rather than only clearing installed. The tree is
  # still on disk, and it is exactly what makes the next install fail, so the removal
  # below has to know the difference between "nothing there" and "a broken tree there".
  if [ -n "$installed" ] && [ ! -d "$dir/skills" ]; then
    echo "  antigravity: $installed is a partial install with no skills — reinstalling"
    installed=""
    partial=1
  fi
  # `|| true` for the reason status() carries it: pipefail makes upstream_version fail on
  # an unreachable network, and the unguarded assignment ends the run under set -e.
  canon="$(upstream_version || true)"

  if [ -z "$canon" ]; then
    if [ "$partial" -eq 1 ]; then
      echo "  antigravity: partial install left in place — cannot reach $UPSTREAM to reinstall from"
    elif [ -n "$installed" ]; then
      echo "  antigravity: kept $installed — cannot reach $UPSTREAM to check for a newer version"
    else
      echo "  antigravity: nothing installed and $UPSTREAM is unreachable — retry when the network is back"
    fi
    return 1
  fi

  if [ "$installed" = "$canon" ]; then
    echo "  antigravity: already on $installed"
    return 0
  fi

  if [ -n "$installed" ]; then
    agy plugin uninstall superpowers >/dev/null 2>&1 \
      || { echo "  antigravity: could not uninstall $installed — run 'agy plugin uninstall superpowers' to see why"; return 1; }
  elif [ "$partial" -eq 1 ]; then
    # agy plugin uninstall is the official removal and is tried first, but a tree that never
    # finished installing may not be registered for it to find, so its status says nothing
    # here. Remove the directory as well, then let the check below decide.
    agy plugin uninstall superpowers >/dev/null 2>&1 || true
    rm -rf "$dir" 2>/dev/null || true
  fi

  # agy plugin install clones into a fresh path and fails with "file exists" when one is
  # already there. That failure is what produces a partial tree, so reaching the install
  # with the directory still present repairs nothing and breaks the same way again. The
  # check also covers a leftover with no package.json, which probe cannot see at all.
  if [ -e "$dir" ]; then
    echo "  antigravity: $dir still exists and agy plugin install cannot clone over it — delete it by hand, then re-run"
    return 1
  fi

  # Say that the old copy is already gone. Between the removal and here, Antigravity has
  # no Superpowers, and a caller told only "install failed" would not know to restore it.
  agy plugin install "$UPSTREAM" >/dev/null 2>&1 || {
    if [ -n "$installed" ]; then
      echo "  antigravity: install failed after $installed was uninstalled — run 'agy plugin install $UPSTREAM' to restore it"
    elif [ "$partial" -eq 1 ]; then
      echo "  antigravity: install failed after the partial tree was removed — run 'agy plugin install $UPSTREAM' to see why"
    else
      echo "  antigravity: install failed — run 'agy plugin install $UPSTREAM' to see why"
    fi
    return 1
  }
  echo "  antigravity: installed from $UPSTREAM"
}

# OpenCode declares its plugins in config rather than through a plugin CLI, so this path
# reports and does not install. A missing declaration is still a failure: OpenCode is on
# the machine and running without Superpowers, and returning 0 for that told install_all
# the harness was done. Gate on the CLI instead of on the config file, so an absent
# OpenCode stays a zero-status SKIP as it does for every other harness — and so an
# installed OpenCode that has not written a config yet is reported rather than skipped.
#
# The config is not rewritten here. Every other path drives a harness's own install
# command, while this one would have to parse and reserialise a file the user maintains,
# losing its layout for a line that is one edit by hand.
install_opencode() {
  command -v opencode >/dev/null 2>&1 || { echo "  opencode: SKIP — CLI not in PATH"; return; }

  local config="$HOME/.config/opencode/opencode.json"
  if [ ! -f "$config" ]; then
    echo "  opencode: no config at $config — create it with a plugin array containing \"$GIT_SPEC\""
    return 1
  fi
  if grep -q "$GIT_SPEC" "$config"; then
    echo "  opencode: already declares $GIT_SPEC"
    return 0
  fi
  echo "  opencode: add \"$GIT_SPEC\" to the plugin array in $config — there is no plugin CLI to do it"
  return 1
}

install_manual() {
  echo "  cursor: no plugin CLI. Reinstall Superpowers from the Cursor plugin UI."
  echo "  kimi: TUI only. Run '/plugins install $UPSTREAM' inside kimi."
  echo "  grok: nothing to do. It reads Claude Code's plugin tree."
}

install_all() {
  # Each harness runs even when an earlier one failed, so one broken CLI does not hide
  # the state of the rest. The collected status is what the script exits with, so a
  # scripted caller can tell a clean install from a partial one.
  local failed=0
  echo "Installing or upgrading where a CLI exists"
  install_claude      || failed=1
  install_codex       || failed=1
  install_antigravity || failed=1
  install_opencode    || failed=1
  echo
  echo "Manual steps"
  install_manual
  echo
  status
  [ "$failed" -eq 0 ] || echo "One or more harnesses failed to install. See the lines above." >&2
  return "$failed"
}

# install exits nonzero when any harness failed, so CI and wrapper scripts can tell a
# clean install from a partial one. The exit is explicit rather than left to `set -e`.
case "${1:-status}" in
  status) status ;;
  install) install_all || exit 1 ;;
  *) echo "usage: $(basename "$0") [status|install]" >&2; exit 2 ;;
esac
