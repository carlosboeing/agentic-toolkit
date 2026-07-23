#!/bin/sh

schedule_resume_execute_claude() (
  _schedule_resume_executable=$1
  _schedule_resume_session_id=$2
  _schedule_resume_project_dir=$3
  _schedule_resume_prompt_file=$4
  cd "$_schedule_resume_project_dir" || return 1
  caffeinate -i "$_schedule_resume_executable" --resume "$_schedule_resume_session_id" --dangerously-skip-permissions --print <"$_schedule_resume_prompt_file"
)

schedule_resume_execute_agy() (
  _schedule_resume_executable=$1
  _schedule_resume_session_id=$2
  _schedule_resume_project_dir=$3
  _schedule_resume_prompt_file=$4
  cd "$_schedule_resume_project_dir" || return 1
  caffeinate -i "$_schedule_resume_executable" --conversation "$_schedule_resume_session_id" --dangerously-skip-permissions --print <"$_schedule_resume_prompt_file"
)

schedule_resume_execute_codex() (
  _schedule_resume_executable=$1
  _schedule_resume_session_id=$2
  _schedule_resume_project_dir=$3
  _schedule_resume_prompt_file=$4
  cd "$_schedule_resume_project_dir" || return 1
  caffeinate -i "$_schedule_resume_executable" exec resume --dangerously-bypass-approvals-and-sandbox "$_schedule_resume_session_id" - <"$_schedule_resume_prompt_file"
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
