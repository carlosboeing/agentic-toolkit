#!/bin/sh

# Emit the idle-guard command prefix for the current platform: caffeinate on
# macOS (prevents idle sleep while an attempt runs), nothing elsewhere. Callers
# word-split the output, so on non-macOS the harness simply runs unguarded.
schedule_resume_idle_guard() (
  case "$(uname -s 2>/dev/null)" in
    Darwin) printf '%s\n' caffeinate -i ;;
    *) : ;;
  esac
)

# Detect whether the target session is currently live, so a scheduled resume
# never collides with a session that is actively being worked. Prints exactly
# one of: absent | idle | active. Claude-only; harnesses without a discoverable
# session registry are reported absent (ungated resume), exactly as before.
schedule_resume_session_liveness() (
  _schedule_resume_liveness_harness=$1
  _schedule_resume_liveness_session_id=$2
  case "$_schedule_resume_liveness_harness" in
    claude)
      schedule_resume_session_liveness_claude "$_schedule_resume_liveness_session_id"
      ;;
    *)
      printf '%s\n' absent
      ;;
  esac
)

# Read Claude Code's own per-session registry (~/.claude/sessions/<pid>.json).
# A file's name is the session PID and its .status is busy/idle. Undocumented
# internal state, so every read degrades gracefully: a missing directory, an
# unparseable file, or a dead PID never wedges a job.
schedule_resume_session_liveness_claude() (
  _schedule_resume_liveness_session_id=$1
  _schedule_resume_liveness_dir=${SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR:-$HOME/.claude/sessions}
  if [ ! -d "$_schedule_resume_liveness_dir" ]; then
    printf '%s\n' absent
    return 0
  fi

  _schedule_resume_liveness_live=0
  _schedule_resume_liveness_active=0
  for _schedule_resume_liveness_file in "$_schedule_resume_liveness_dir"/*.json; do
    [ -f "$_schedule_resume_liveness_file" ] || continue
    # Emit "<pid>\n<status>" for a matching entry; skip files that do not parse
    # or do not carry the target UUID. A missing status becomes "unknown".
    _schedule_resume_liveness_row=$(jq -r \
      --arg sid "$_schedule_resume_liveness_session_id" \
      'select(.sessionId == $sid) | (.pid | tostring), (.status // "unknown")' \
      "$_schedule_resume_liveness_file" 2>/dev/null) || continue
    [ -n "$_schedule_resume_liveness_row" ] || continue

    _schedule_resume_liveness_pid=
    _schedule_resume_liveness_status=
    {
      IFS= read -r _schedule_resume_liveness_pid &&
        IFS= read -r _schedule_resume_liveness_status
    } <<LIVENESS_ROW
$_schedule_resume_liveness_row
LIVENESS_ROW

    case "$_schedule_resume_liveness_pid" in
      '' | *[!0-9]*) continue ;;
    esac
    kill -0 "$_schedule_resume_liveness_pid" 2>/dev/null || continue

    _schedule_resume_liveness_live=1
    if [ "$_schedule_resume_liveness_status" != idle ]; then
      _schedule_resume_liveness_active=1
    fi
  done

  if [ "$_schedule_resume_liveness_active" -eq 1 ]; then
    printf '%s\n' active
  elif [ "$_schedule_resume_liveness_live" -eq 1 ]; then
    printf '%s\n' idle
  else
    printf '%s\n' absent
  fi
)

schedule_resume_execute_claude() (
  _schedule_resume_executable=$1
  _schedule_resume_session_id=$2
  _schedule_resume_project_dir=$3
  _schedule_resume_prompt_file=$4
  cd "$_schedule_resume_project_dir" || return 1
  # shellcheck disable=SC2046  # intentional word-split of the idle-guard prefix
  set -- $(schedule_resume_idle_guard) "$_schedule_resume_executable" --resume "$_schedule_resume_session_id" --dangerously-skip-permissions --print
  "$@" <"$_schedule_resume_prompt_file"
)

schedule_resume_execute_agy() (
  _schedule_resume_executable=$1
  _schedule_resume_session_id=$2
  _schedule_resume_project_dir=$3
  _schedule_resume_prompt_file=$4
  cd "$_schedule_resume_project_dir" || return 1
  # shellcheck disable=SC2046  # intentional word-split of the idle-guard prefix
  set -- $(schedule_resume_idle_guard) "$_schedule_resume_executable" --conversation "$_schedule_resume_session_id" --dangerously-skip-permissions --print
  "$@" <"$_schedule_resume_prompt_file"
)

schedule_resume_execute_codex() (
  _schedule_resume_executable=$1
  _schedule_resume_session_id=$2
  _schedule_resume_project_dir=$3
  _schedule_resume_prompt_file=$4
  cd "$_schedule_resume_project_dir" || return 1
  # shellcheck disable=SC2046  # intentional word-split of the idle-guard prefix
  set -- $(schedule_resume_idle_guard) "$_schedule_resume_executable" exec resume --dangerously-bypass-approvals-and-sandbox "$_schedule_resume_session_id" -
  "$@" <"$_schedule_resume_prompt_file"
)

schedule_resume_execute_target() (
  _schedule_resume_target=$1
  shift

  case "$_schedule_resume_target" in
    claude)
      schedule_resume_execute_claude "$@"
      ;;
    agy)
      schedule_resume_execute_agy "$@"
      ;;
    codex)
      schedule_resume_execute_codex "$@"
      ;;
    *)
      printf 'unsupported target harness: %s\n' "$_schedule_resume_target" >&2
      return 64
      ;;
  esac
)

classify_result() (
  _schedule_resume_exit_status=$1
  _schedule_resume_completion_policy=$2
  shift 2

  if [ "$_schedule_resume_exit_status" -eq 0 ]; then
    if [ "$_schedule_resume_completion_policy" = sentinel-output ]; then
      _schedule_resume_stdout_file=$1
      if grep -Fxq "$SCHEDULE_RESUME_SENTINEL" "$_schedule_resume_stdout_file" 2>/dev/null; then
        printf '%s\n' success
      else
        printf '%s\n' incomplete_retryable
      fi
    else
      printf '%s\n' success
    fi
  elif grep -Eiq 'authenticat|not logged in|log in required|login required|unauthorized|invalid (api )?(key|token)|(^|[^0-9])401([^0-9]|$)' "$@"; then
    printf '%s\n' authentication_terminal
  elif grep -Eiq '(session|conversation).*(not found|does not exist|missing|invalid)|no (such )?(session|conversation)' "$@"; then
    printf '%s\n' session_terminal
  elif grep -Eiq 'permission denied|operation not permitted|approval required|sandbox.*(denied|blocked)|access denied' "$@"; then
    printf '%s\n' permission_terminal
  elif grep -Eiq "(usage|rate) limit (reached|exceeded)|quota (reached|exceeded)|you've hit your( usage)? limit|too many requests|resource.exhausted" "$@"; then
    printf '%s\n' quota_retryable
  elif grep -Eiq 'service temporarily unavailable|service unavailable|service overloaded|server overloaded|at capacity|capacity limit (reached|exceeded)|service busy|try again later' "$@"; then
    printf '%s\n' availability_retryable
  elif grep -Eiq '\btimed out\b|\btimeout\b|\betimedout\b|\beconnreset\b|\beconnrefused\b|\benetunreach\b|socket hang up|connection (error|reset|refused|closed)|network (error|unreachable)|fetch failed|bad gateway|gateway time(-| )?out|internal server error|\boverloaded(_error)?\b' "$@"; then
    printf '%s\n' transient_retryable
  else
    printf '%s\n' failure_terminal
  fi
)
