#!/usr/bin/env bash
# Keep a Mac awake on AC power for remote agent sessions, and restore the
# previous setting afterwards. Changes only the AC "sleep" timer.
set -euo pipefail

PMSET="${MAC_STAY_AWAKE_PMSET:-pmset}"
SUDO="${MAC_STAY_AWAKE_SUDO:-sudo}"
STATE_DIR="${MAC_STAY_AWAKE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/agentic-toolkit}"
STATE_FILE="$STATE_DIR/mac-stay-awake.previous-ac-sleep"
LID_NOTE="Note: closing the lid still puts a laptop to sleep, unless it is in clamshell mode with an external display."

usage() {
  cat <<'USAGE'
Usage: mac-stay-awake.sh on|off|status

  on      Save the current AC sleep timer, then stop idle sleep on AC power.
  off     Restore the saved AC sleep timer and delete the saved value.
  status  Show the AC sleep and display sleep timers, what holds the Mac awake,
          and the saved value.

Display sleep, battery settings and lid sleep are not changed.
USAGE
}

# Print one setting from the "AC Power:" section of `pmset -g custom`.
ac_value() {
  "$PMSET" -g custom | awk -v key="$1" '
    /^[^ \t].*:[ \t]*$/ { section = $0; sub(/[ \t]+$/, "", section); next }
    section == "AC Power:" && $1 == key { print $2; exit }'
}

is_minutes() { [[ "$1" =~ ^[0-9]+$ ]]; }

saved_value() {
  [[ -f "$STATE_FILE" ]] || return 1
  local value
  value="$(tr -d '[:space:]' < "$STATE_FILE")"
  if ! is_minutes "$value"; then
    echo "Saved value in $STATE_FILE is not a number of minutes: '$value'" >&2
    exit 1
  fi
  printf '%s\n' "$value"
}

cmd_on() {
  local current created=0
  current="$(ac_value sleep)"
  if ! is_minutes "$current"; then
    echo "Could not read the AC sleep timer from 'pmset -g custom'." >&2
    exit 1
  fi

  if [[ ! -f "$STATE_FILE" ]]; then
    if [[ "$current" == 0 ]]; then
      echo "AC sleep is already 0 (never). Nothing to save or change."
      echo "$LID_NOTE"
      return 0
    fi
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$current" > "$STATE_FILE"
    created=1
  else
    echo "Keeping the value saved earlier ($(saved_value) min)."
  fi

  if [[ "$current" != 0 ]]; then
    if ! "$SUDO" "$PMSET" -c sleep 0; then
      [[ "$created" == 1 ]] && rm -f "$STATE_FILE"
      echo "pmset failed. Nothing changed." >&2
      exit 1
    fi
  fi
  [[ "$created" == 1 ]] && echo "Saved the previous AC sleep timer ($current min) to $STATE_FILE"
  echo "AC sleep is now 0 (never). Revert with: $0 off"
  echo "$LID_NOTE"
}

cmd_off() {
  local saved
  if ! saved="$(saved_value)"; then
    echo "No saved value in $STATE_FILE. Nothing changed." >&2
    echo "Current AC sleep: $(ac_value sleep) min. To set it by hand: sudo pmset -c sleep <minutes>" >&2
    exit 1
  fi
  "$SUDO" "$PMSET" -c sleep "$saved"
  rm -f "$STATE_FILE"
  echo "Restored AC sleep to $saved min."
}

cmd_status() {
  local saved blockers
  echo "AC sleep:         $(ac_value sleep) min (0 means never)"
  echo "AC display sleep: $(ac_value displaysleep) min"
  blockers="$("$PMSET" -g | awk '$1 == "sleep" { $1 = ""; $2 = ""; sub(/^ +/, ""); print; exit }')"
  echo "Held awake by:    ${blockers:-nothing}"
  if saved="$(saved_value)"; then
    echo "Saved value:      $saved min (run '$0 off' to restore)"
  else
    echo "Saved value:      none"
  fi
  echo "$LID_NOTE"
}

if ! command -v "$PMSET" >/dev/null 2>&1; then
  echo "pmset not found. This script supports macOS only." >&2
  exit 1
fi

case "${1:-}" in
  on) cmd_on ;;
  off) cmd_off ;;
  status) cmd_status ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
