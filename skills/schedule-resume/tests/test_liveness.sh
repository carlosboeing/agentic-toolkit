#!/bin/sh

. "$LIB_DIR/common.sh"
. "$LIB_DIR/adapters.sh"

liveness_root="$TEST_TMPDIR/liveness"
mkdir -p "$liveness_root"

# Craft one Claude session-registry file (~/.claude/sessions/<pid>.json). Pass
# the literal __nostatus__ to omit the status field entirely.
write_session() {
  _ws_dir=$1
  _ws_pid=$2
  _ws_sid=$3
  _ws_status=$4
  if [ "$_ws_status" = __nostatus__ ]; then
    jq -n --argjson pid "$_ws_pid" --arg sid "$_ws_sid" \
      '{pid: $pid, sessionId: $sid, cwd: "/x", kind: "interactive", updatedAt: 0, statusUpdatedAt: 0}' \
      >"$_ws_dir/$_ws_pid.json"
  else
    jq -n --argjson pid "$_ws_pid" --arg sid "$_ws_sid" --arg status "$_ws_status" \
      '{pid: $pid, sessionId: $sid, cwd: "/x", kind: "interactive", status: $status, updatedAt: 0, statusUpdatedAt: 0}' \
      >"$_ws_dir/$_ws_pid.json"
  fi
}

# Run detection with the fixture directory scoped to this call only, so the
# override never leaks into other test groups sharing this shell.
liveness() (
  _lv_harness=$1
  _lv_dir=$2
  _lv_sid=$3
  SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR=$_lv_dir
  export SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR
  schedule_resume_session_liveness "$_lv_harness" "$_lv_sid"
)

# No entry carries the target UUID -> absent.
no_match_dir="$liveness_root/no-match"
mkdir -p "$no_match_dir"
sleep 30 &
no_match_pid=$!
write_session "$no_match_dir" "$no_match_pid" other-session busy
assert_equal absent "$(liveness claude "$no_match_dir" target-session)" "no matching sessionId is absent"
kill "$no_match_pid" 2>/dev/null || :
wait "$no_match_pid" 2>/dev/null || :

# Matching entry whose PID has been reaped -> absent.
dead_dir="$liveness_root/dead-pid"
mkdir -p "$dead_dir"
sleep 30 &
dead_pid=$!
kill "$dead_pid" 2>/dev/null || :
wait "$dead_pid" 2>/dev/null || :
write_session "$dead_dir" "$dead_pid" target-session busy
assert_equal absent "$(liveness claude "$dead_dir" target-session)" "matched but dead PID is absent"

# Matching entry, live PID, status busy -> active.
busy_dir="$liveness_root/busy"
mkdir -p "$busy_dir"
sleep 30 &
busy_pid=$!
write_session "$busy_dir" "$busy_pid" target-session busy
assert_equal active "$(liveness claude "$busy_dir" target-session)" "matched live busy PID is active"
kill "$busy_pid" 2>/dev/null || :
wait "$busy_pid" 2>/dev/null || :

# Matching entry, live PID, status idle -> idle.
idle_dir="$liveness_root/idle"
mkdir -p "$idle_dir"
sleep 30 &
idle_pid=$!
write_session "$idle_dir" "$idle_pid" target-session idle
assert_equal idle "$(liveness claude "$idle_dir" target-session)" "matched live idle PID is idle"
kill "$idle_pid" 2>/dev/null || :
wait "$idle_pid" 2>/dev/null || :

# Matching entry, live PID, status field missing -> active (conservative).
missing_status_dir="$liveness_root/missing-status"
mkdir -p "$missing_status_dir"
sleep 30 &
missing_status_pid=$!
write_session "$missing_status_dir" "$missing_status_pid" target-session __nostatus__
assert_equal active "$(liveness claude "$missing_status_dir" target-session)" "matched live PID with missing status is active"
kill "$missing_status_pid" 2>/dev/null || :
wait "$missing_status_pid" 2>/dev/null || :

# Two live entries for one UUID, one of them busy -> active.
multi_dir="$liveness_root/multi"
mkdir -p "$multi_dir"
sleep 30 &
multi_idle_pid=$!
sleep 30 &
multi_busy_pid=$!
write_session "$multi_dir" "$multi_idle_pid" target-session idle
write_session "$multi_dir" "$multi_busy_pid" target-session busy
assert_equal active "$(liveness claude "$multi_dir" target-session)" "any live busy entry among matches is active"
kill "$multi_idle_pid" "$multi_busy_pid" 2>/dev/null || :
wait "$multi_idle_pid" 2>/dev/null || :
wait "$multi_busy_pid" 2>/dev/null || :

# Sessions directory does not exist -> absent (fail-open).
assert_equal absent "$(liveness claude "$liveness_root/does-not-exist" target-session)" "missing sessions directory is absent"

# Non-claude harness is ungated even with a live busy match -> absent.
non_claude_dir="$liveness_root/non-claude"
mkdir -p "$non_claude_dir"
sleep 30 &
non_claude_pid=$!
write_session "$non_claude_dir" "$non_claude_pid" target-session busy
assert_equal absent "$(liveness codex "$non_claude_dir" target-session)" "non-claude harness is ungated (absent)"
assert_equal absent "$(liveness agy "$non_claude_dir" target-session)" "agy harness is ungated (absent)"
kill "$non_claude_pid" 2>/dev/null || :
wait "$non_claude_pid" 2>/dev/null || :

pass "Claude session liveness detection"
