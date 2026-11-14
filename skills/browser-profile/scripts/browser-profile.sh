#!/usr/bin/env bash
# browser-profile.sh — attach a Playwright CLI session to a signed-in Chrome
# profile through the Playwright extension.
#
# No extension token is used or stored. Every attach opens the extension's
# connect page in the chosen profile and waits for the user to click Allow.
# A desktop notification tells the user that the click is needed.
#
# Page snapshots and other CLI output go to a private folder per session,
# outside the project, because they hold content from signed-in sites. The
# folder is deleted when the session is closed.
#
# Usage:
#   browser-profile.sh list
#   browser-profile.sh open <alias> [session]
#   browser-profile.sh close <session> [--close-tabs]
#
# Setup:
#   browser-profile.sh check [alias]              every requirement, with a fix for each gap
#   browser-profile.sh profiles                   the Chrome profiles on this machine
#   browser-profile.sh install-extension <alias>  open the extension's store page in that profile
#
# Aliases come from a machine-local file, one per line:
#   <alias> = <Chrome profile directory> [| <label>]
#
# Environment:
#   BROWSER_PROFILE_CONF        alias file (default: ~/.config/agentic-toolkit/browser-profiles.conf)
#   BROWSER_PROFILE_CLI         Playwright CLI command (default: playwright-cli)
#   BROWSER_PROFILE_WAIT        seconds to wait for the Allow click (default: 100)
#   BROWSER_PROFILE_IDLE_MS     detach after this long without a command (default: 1800000)
#   BROWSER_PROFILE_CHROME_DIR  Chrome user data directory (default: per platform)
#   BROWSER_PROFILE_NOTIFY      0 switches the desktop notification off (default: 1)
set -euo pipefail

EXTENSION_ID="mmlmfjhmonkocbjadbfplnigmagldckm"
STORE_URL="https://chromewebstore.google.com/detail/playwright-extension/$EXTENSION_ID"
CLI_INSTALL="npm install -g @playwright/cli@latest"
MIN_CLI_VERSION="0.1.24"
CONF="${BROWSER_PROFILE_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/agentic-toolkit/browser-profiles.conf}"
CLI="${BROWSER_PROFILE_CLI:-playwright-cli}"
WAIT_SECONDS="${BROWSER_PROFILE_WAIT:-100}"
IDLE_MS="${BROWSER_PROFILE_IDLE_MS:-1800000}"
OUTPUT_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/agentic-toolkit/browser-profile"

usage() {
  cat >&2 <<'EOF'
Usage:
  browser-profile.sh list
  browser-profile.sh open <alias> [session]
  browser-profile.sh close <session> [--close-tabs]
Setup:
  browser-profile.sh check [alias]
  browser-profile.sh profiles
  browser-profile.sh install-extension <alias>
EOF
}

die() {
  printf 'browser-profile: %s\n' "$*" >&2
  exit 1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

is_safe_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

# Print "<profile directory>|<label>" for an alias, or return 1.
lookup() {
  local want="$1" line key
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    [[ "$line" == *=* ]] || continue
    key="$(trim "${line%%=*}")"
    if [ "$key" = "$want" ]; then
      trim "${line#*=}"
      return 0
    fi
  done <"$CONF"
  return 1
}

require_conf() {
  [ -f "$CONF" ] || die "no alias file at $CONF. Create it with one line per profile: <alias> = <Chrome profile directory> | <label>"
}

chrome_data_dir() {
  if [ -n "${BROWSER_PROFILE_CHROME_DIR:-}" ]; then
    printf '%s' "$BROWSER_PROFILE_CHROME_DIR"
    return
  fi
  case "$(uname -s)" in
    Darwin) printf '%s' "$HOME/Library/Application Support/Google/Chrome" ;;
    Linux) printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/google-chrome" ;;
    *) die "unsupported platform. Set BROWSER_PROFILE_CHROME_DIR to Chrome's user data directory" ;;
  esac
}

# Print "ready", or the reason the profile cannot be opened.
profile_state() {
  local profile_dir="$1" data_dir
  data_dir="$(chrome_data_dir)"
  if [[ ! "$profile_dir" =~ ^[A-Za-z0-9][A-Za-z0-9\ ._-]*$ ]]; then
    printf 'invalid profile directory name'
  elif [ ! -d "$data_dir/$profile_dir" ]; then
    printf 'profile not found'
  elif [ ! -d "$data_dir/$profile_dir/Extensions/$EXTENSION_ID" ]; then
    printf 'extension not installed'
  else
    printf 'ready'
  fi
}

# version_ge A B: succeeds when A >= B, comparing three numeric fields.
version_ge() {
  local IFS=. i x y
  local -a a b
  read -r -a a <<<"$1"
  read -r -a b <<<"$2"
  for i in 0 1 2; do
    x="${a[i]:-0}"
    y="${b[i]:-0}"
    x="${x%%[!0-9]*}"
    y="${y%%[!0-9]*}"
    if ((10#${x:-0} > 10#${y:-0})); then return 0; fi
    if ((10#${x:-0} < 10#${y:-0})); then return 1; fi
  done
  return 0
}

# Print the installed Playwright CLI version, or nothing when it is absent.
cli_version() {
  command -v "$CLI" >/dev/null 2>&1 || return 0
  "$CLI" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true
}

require_cli() {
  local version
  version="$(cli_version)"
  [ -n "$version" ] || die "Playwright CLI not found ($CLI). Install it with: $CLI_INSTALL"
  version_ge "$version" "$MIN_CLI_VERSION" || die "Playwright CLI $version is older than $MIN_CLI_VERSION, the oldest version tested. Update it with: $CLI_INSTALL"
}

# Print the aliases that point to a profile directory, comma-separated.
aliases_for() {
  local want="$1" line key value found=""
  [ -f "$CONF" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    [[ "$line" == *=* ]] || continue
    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"
    if [ "$(trim "${value%%|*}")" = "$want" ]; then found="${found:+$found,}$key"; fi
  done <"$CONF"
  printf '%s' "$found"
}

# Succeeds when `playwright-cli list` on stdin shows the session attached to
# an existing browser. A browser the CLI launched itself has no "(attached)".
session_is_attached() {
  awk -v want="- $1:" '
    /^- / { in_block = ($0 == want) }
    in_block && /browser-type:.*\(attached\)/ { found = 1 }
    END { exit found ? 0 : 1 }
  '
}

# A session that is still waiting for approval is not listed by the CLI, so
# its background process has to be stopped by name.
stop_session_process() {
  pkill -f "cliDaemon\\.js $1( |\$)" 2>/dev/null || true
}

# The agent's own request for the click can be missed or left out, so the
# helper tells the user directly. Best effort: a missing notifier is ignored.
notify_user() {
  local text="$1" title="Agent needs you: click Allow in Chrome"
  [ "${BROWSER_PROFILE_NOTIFY:-1}" != "0" ] || return 0
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'on run argv' \
      -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "Glass"' \
      -e 'end run' "$title" "$text" >/dev/null 2>&1 || true
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$text" >/dev/null 2>&1 || true
  fi
}

# Stop a session that failed part-way and remove what it wrote.
abandon_session() {
  stop_session_process "$1"
  rm -rf "${OUTPUT_ROOT:?}/$1"
}

cmd_list() {
  local line key value profile_dir label
  require_conf
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    [[ "$line" == *=* ]] || continue
    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"
    profile_dir="$(trim "${value%%|*}")"
    label=""
    if [[ "$value" == *"|"* ]]; then label="$(trim "${value#*|}")"; fi
    printf '%s\t%s\t%s\t%s\n' "$key" "$profile_dir" "$(profile_state "$profile_dir")" "$label"
  done <"$CONF"
}

# Report every requirement. Each gap is followed by a "fix:" line that says
# exactly what to do. Exit 1 when anything is missing.
cmd_check() {
  local only="${1:-}" problems=0 found=0 version line key value profile_dir label state

  version="$(cli_version)"
  if [ -z "$version" ]; then
    printf 'cli\tmissing\t%s\n' "$CLI"
    printf '  fix: %s\n' "$CLI_INSTALL"
    problems=1
  elif ! version_ge "$version" "$MIN_CLI_VERSION"; then
    printf 'cli\told\t%s, needs %s or later\n' "$version" "$MIN_CLI_VERSION"
    printf '  fix: %s\n' "$CLI_INSTALL"
    problems=1
  else
    printf 'cli\tok\t%s\n' "$version"
  fi

  if [ ! -f "$CONF" ]; then
    printf 'aliases\tmissing\t%s\n' "$CONF"
    printf '  fix: run "browser-profile.sh profiles" to see the Chrome profiles on this machine. Then create %s with one line per profile: <alias> = <Chrome profile directory> | <label>\n' "$CONF"
    return 1
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    [[ "$line" == *=* ]] || continue
    key="$(trim "${line%%=*}")"
    if [ -n "$only" ] && [ "$key" != "$only" ]; then continue; fi
    found=1
    value="$(trim "${line#*=}")"
    profile_dir="$(trim "${value%%|*}")"
    label=""
    if [[ "$value" == *"|"* ]]; then label="$(trim "${value#*|}")"; fi
    state="$(profile_state "$profile_dir")"
    printf '%s\t%s\t%s\t%s\n' "$key" "$state" "$profile_dir" "$label"
    case "$state" in
      ready) ;;
      "extension not installed")
        printf '  fix: run "browser-profile.sh install-extension %s". It opens the Playwright Extension page in that profile, where the user clicks "Add to Chrome"\n' "$key"
        problems=1
        ;;
      *)
        printf '  fix: correct the profile directory for "%s" in %s. "browser-profile.sh profiles" lists the valid ones\n' "$key" "$CONF"
        problems=1
        ;;
    esac
  done <"$CONF"

  if [ "$found" -eq 0 ]; then
    printf '%s\tno alias\t%s\n' "${only:-aliases}" "$CONF"
    printf '  fix: run "browser-profile.sh profiles", let the user choose a profile, then add a line to %s: %s = <Chrome profile directory> | <label>\n' "$CONF" "${only:-<alias>}"
    problems=1
  fi
  return "$problems"
}

# List the Chrome profiles on this machine: directory, Chrome's display name,
# extension state and aliases. Account addresses are never printed.
cmd_profiles() {
  local data_dir path dir name names="" ext aliases
  data_dir="$(chrome_data_dir)"
  [ -d "$data_dir" ] || die "Chrome's user data directory was not found at $data_dir. Is Google Chrome installed?"
  if command -v python3 >/dev/null 2>&1; then
    names="$(python3 -c '
import json, sys
try:
    cache = json.load(open(sys.argv[1], encoding="utf-8"))["profile"]["info_cache"]
except Exception:
    cache = {}
for directory, info in cache.items():
    name = " ".join(str(info.get("name", "")).split())
    print(directory + chr(9) + name)
' "$data_dir/Local State" 2>/dev/null || true)"
  fi
  for path in "$data_dir"/Default "$data_dir"/Profile\ *; do
    [ -f "$path/Preferences" ] || continue
    dir="${path##*/}"
    name="$(printf '%s\n' "$names" | awk -F '\t' -v d="$dir" '$1 == d { print $2; exit }')"
    if [ -d "$path/Extensions/$EXTENSION_ID" ]; then ext="extension installed"; else ext="extension not installed"; fi
    aliases="$(aliases_for "$dir")"
    printf '%s\t%s\t%s\t%s\n' "$dir" "${name:--}" "$ext" "${aliases:--}"
  done
}

# Open the extension's Chrome Web Store page in the aliased profile. The user
# installs it there: that click is what permits agent access to the profile.
cmd_install_extension() {
  local alias_name="${1:-}" entry profile_dir state

  [ -n "$alias_name" ] || { usage; exit 2; }
  require_conf
  is_safe_name "$alias_name" || die "'$alias_name' is not a profile alias. Run: browser-profile.sh list"
  entry="$(lookup "$alias_name")" || die "no alias '$alias_name' in $CONF. Run: browser-profile.sh list"
  profile_dir="$(trim "${entry%%|*}")"
  state="$(profile_state "$profile_dir")"
  case "$state" in
    ready)
      printf 'The Playwright Extension is already installed in Chrome profile "%s" (%s).\n' "$alias_name" "$profile_dir"
      return 0
      ;;
    "extension not installed") ;;
    *) die "alias '$alias_name' points to '$profile_dir': $state" ;;
  esac

  case "$(uname -s)" in
    Darwin) open -na "Google Chrome" --args --profile-directory="$profile_dir" "$STORE_URL" ;;
    Linux) google-chrome --profile-directory="$profile_dir" "$STORE_URL" >/dev/null 2>&1 & ;;
    *) die "unsupported platform. Open $STORE_URL in that Chrome profile by hand" ;;
  esac
  printf 'Opened the Playwright Extension page in Chrome profile "%s" (%s).\n' "$alias_name" "$profile_dir"
  printf 'The user clicks "Add to Chrome" there. Then run: browser-profile.sh check %s\n' "$alias_name"
}

cmd_open() {
  local alias_name="${1:-}" session="${2:-}"
  local entry profile_dir label state attach_log attach_pid waited name output_dir

  [ -n "$alias_name" ] || { usage; exit 2; }
  require_conf
  is_safe_name "$alias_name" || die "'$alias_name' is not a profile alias. Run: browser-profile.sh list"
  entry="$(lookup "$alias_name")" || die "no alias '$alias_name' in $CONF. Run: browser-profile.sh list"
  profile_dir="$(trim "${entry%%|*}")"
  label=""
  if [[ "$entry" == *"|"* ]]; then label="$(trim "${entry#*|}")"; fi

  state="$(profile_state "$profile_dir")"
  case "$state" in
    ready) ;;
    "extension not installed") die "the Playwright extension is not installed in Chrome profile '$profile_dir'. Installing it there is what permits agent access" ;;
    *) die "alias '$alias_name' points to '$profile_dir': $state" ;;
  esac

  if [ -z "$session" ]; then
    session="$(printf '%s-%04x' "$alias_name" "$((RANDOM % 65536))")"
  fi
  is_safe_name "$session" || die "session name must use lowercase letters, digits and hyphens"

  require_cli

  # Inherited Playwright settings can redirect the connection. The isolated
  # setting outranks the extension, and a token would skip the Allow click.
  while IFS= read -r name; do
    unset "$name"
  done < <(compgen -e | grep '^PLAYWRIGHT_MCP_' || true)
  export PLAYWRIGHT_MCP_PROFILE_DIR_NAME="$profile_dir"

  # Keep page output out of the project. Folders left by sessions that were
  # never closed are removed after a day.
  output_dir="$OUTPUT_ROOT/$session"
  (umask 077 && mkdir -p "$OUTPUT_ROOT")
  find "$OUTPUT_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
  (umask 077 && mkdir -p "$output_dir")
  chmod 700 "$output_dir"
  export PLAYWRIGHT_MCP_OUTPUT_DIR="$output_dir"

  notify_user "Profile \"$alias_name\"${label:+ ($label)}. Click Allow on the Playwright connect page. Select no tab."
  printf 'Waiting up to %ss for the Allow click in Chrome profile "%s" (%s%s).\n' \
    "$WAIT_SECONDS" "$alias_name" "$profile_dir" "${label:+, $label}" >&2

  attach_log="$(mktemp "${TMPDIR:-/tmp}/browser-profile.XXXXXX")"
  "$CLI" attach --extension=chrome --session="$session" --idle-timeout="$IDLE_MS" >"$attach_log" 2>&1 &
  attach_pid=$!
  trap 'kill "$attach_pid" 2>/dev/null; abandon_session "$session"; rm -f "$attach_log"; exit 130' INT TERM

  waited=0
  while kill -0 "$attach_pid" 2>/dev/null; do
    if [ "$waited" -ge "$WAIT_SECONDS" ]; then
      kill "$attach_pid" 2>/dev/null || true
      abandon_session "$session"
      rm -f "$attach_log"
      die "nobody clicked Allow within ${WAIT_SECONDS}s. The connection was cancelled. Close the leftover Playwright connect page in Chrome"
    fi
    sleep 1
    waited=$((waited + 1))
  done

  if ! wait "$attach_pid"; then
    cat "$attach_log" >&2
    rm -f "$attach_log"
    abandon_session "$session"
    die "the Playwright CLI could not attach"
  fi
  rm -f "$attach_log"
  trap - INT TERM

  if ! "$CLI" list 2>/dev/null | session_is_attached "$session"; then
    "$CLI" -s="$session" close >/dev/null 2>&1 || true
    abandon_session "$session"
    die "the session did not connect through the extension, so it is not the signed-in profile. It was closed"
  fi

  printf 'session: %s\n' "$session"
  printf 'profile: %s (%s%s)\n' "$alias_name" "$profile_dir" "${label:+, $label}"
  printf 'run:     %s -s=%s <command>\n' "$CLI" "$session"
  printf 'output:  %s\n' "$output_dir"
  printf 'finish:  browser-profile.sh close %s\n' "$session"
}

cmd_close() {
  local session="${1:-}" option="${2:-}" tabs i

  [ -n "$session" ] || { usage; exit 2; }
  is_safe_name "$session" || die "session name must use lowercase letters, digits and hyphens"
  case "$option" in
    "" | --close-tabs) ;;
    *) usage; exit 2 ;;
  esac

  if [ "$option" = "--close-tabs" ]; then
    tabs="$("$CLI" -s="$session" tab-list 2>/dev/null | grep -c '^- [0-9]' || true)"
    i=0
    while [ "$i" -lt "${tabs:-0}" ]; do
      "$CLI" -s="$session" tab-close >/dev/null 2>&1 || break
      i=$((i + 1))
    done
  fi
  "$CLI" -s="$session" detach >/dev/null 2>&1 || true
  abandon_session "$session"
  printf 'closed: %s\n' "$session"
}

case "${1:-}" in
  list) shift; cmd_list "$@" ;;
  open) shift; cmd_open "$@" ;;
  close) shift; cmd_close "$@" ;;
  check) shift; cmd_check "$@" ;;
  profiles) shift; cmd_profiles "$@" ;;
  install-extension) shift; cmd_install_extension "$@" ;;
  help | --help | -h) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac
