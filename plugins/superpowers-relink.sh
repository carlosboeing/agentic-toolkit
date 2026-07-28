#!/usr/bin/env bash
#
# Restore the hand-crafted "live content" wiring for the superpowers plugin in
# Codex and Antigravity, both of which materialize a local copy that a plain
# `git pull` in the canonical repo does not reach on its own.
#
#   Codex:       loads plugins from a cache snapshot, not the marketplace source.
#                Keep the version dir real (satisfies its "installed" check) but
#                symlink the content subdirs to canonical.
#   Antigravity: loads a plugin dir only if it has a top-level plugin.json, and
#                uses a different manifest format than the canonical repo. Rebuild
#                a thin plugin dir (real plugin.json) with content symlinked out.
#
# Both wirings can be clobbered by the harness's own commands (Codex:
# `codex plugin marketplace upgrade` / remove / add; Antigravity: a re-import).
# Re-run this script afterwards. Idempotent -- safe to run repeatedly.
#
# Claude Code needs nothing here: its installPath points straight at canonical.
#
#   Kimi Code:  runs plugins from its managed copy, but a whole-directory
#               symlink at that path passes its symlink-resolution check, so
#               the managed "copy" can point straight at canonical. Requires
#               the plugin to already be registered (install natively first:
#               /plugins install https://github.com/obra/superpowers). A
#               `/plugins` update or reinstall clobbers the symlink — re-run.
#
set -euo pipefail

CANON="~/Projects/agentic-toolkit/plugins/superpowers"
CONTENT=(skills hooks docs assets)

# ----- Codex -----------------------------------------------------------------
CODEX_PARENT="$HOME/.codex/plugins/cache/superpowers-dev/superpowers"
CODEX_SLOT="$(find "$CODEX_PARENT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1 || true)"

if [[ -n "${CODEX_SLOT:-}" && -d "$CODEX_SLOT" ]]; then
  for d in "${CONTENT[@]}"; do
    [[ -e "$CANON/$d" ]] || continue
    [[ -e "$CODEX_SLOT/$d" || -L "$CODEX_SLOT/$d" ]] && rm -rf "$CODEX_SLOT/$d"
    ln -sfn "$CANON/$d" "$CODEX_SLOT/$d"
  done
  echo "codex:       relinked content subdirs in $CODEX_SLOT"
else
  echo "codex:       SKIP -- no snapshot under $CODEX_PARENT" >&2
  echo "             install first: codex plugin marketplace add \"$CANON\" && codex plugin add superpowers@superpowers-dev" >&2
fi

# ----- Antigravity -----------------------------------------------------------
GP="$HOME/.gemini/config/plugins/superpowers"
[[ -L "$GP" ]] && rm "$GP"          # drop any stale whole-repo symlink
mkdir -p "$GP"
printf '{\n  "name": "superpowers"\n}\n' > "$GP/plugin.json"
ln -sfn "$CANON/skills"            "$GP/skills"
ln -sfn "$CANON/hooks"             "$GP/hooks"
ln -sfn "$CANON/hooks/hooks.json"  "$GP/hooks.json"
echo "antigravity: rebuilt plugin dir at $GP"

# ----- Kimi Code -------------------------------------------------------------
KP="$HOME/.kimi-code/plugins/managed/superpowers"
if [[ -d "$HOME/.kimi-code/plugins" ]]; then
  if [[ -L "$KP" && "$(readlink "$KP")" == "$CANON" ]]; then
    echo "kimi:        already linked to canonical"
  else
    if [[ -e "$KP" && ! -L "$KP" ]]; then
      mv "$KP" "$KP.bak-$(date +%Y%m%d%H%M%S)"
      echo "kimi:        native managed copy moved aside to $KP.bak-*"
    fi
    ln -sfn "$CANON" "$KP"
    echo "kimi:        managed dir linked to canonical"
  fi
else
  echo "kimi:        SKIP -- ~/.kimi-code/plugins not found" >&2
  echo "             install first: /plugins install https://github.com/obra/superpowers" >&2
fi

echo "done. Restart Codex and Antigravity to pick up the changes."
