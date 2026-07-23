#!/bin/sh

_schedule_resume_is_approved_status() (
  case "${1-}" in
    scheduled | running | retrying | completed | failed | cancelled)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
)

_schedule_resume_validate_manifest() (
  printf '%s\n' "$1" | jq -e '
    type == "object" and
    keys == [
      "completion_policy",
      "created_at",
      "first_attempt_at",
      "harness_executable",
      "job_id",
      "permissions_mode",
      "project_dir",
      "prompt_file",
      "retry_interval_seconds",
      "retry_policy",
      "schedule_type",
      "session_id",
      "status",
      "target_harness"
    ] and
    (.job_id | type == "string") and
    (.target_harness | type == "string") and
    (.harness_executable | type == "string" and startswith("/")) and
    (.session_id | type == "string") and
    (.project_dir | type == "string") and
    (.prompt_file | type == "string") and
    (.schedule_type | type == "string") and
    (.first_attempt_at | type == "string") and
    (.retry_interval_seconds | type == "number" and . > 0 and floor == .) and
    (.retry_policy | type == "string") and
    (.completion_policy | type == "string") and
    (.permissions_mode | type == "string") and
    (.created_at | type == "string") and
    (.status | type == "string")
  ' >/dev/null
)

_schedule_resume_validate_status_json() (
  printf '%s\n' "$1" | jq -e '
    type == "object" and
    has("status") and
    has("attempt_count") and
    has("last_exit_code") and
    has("last_classification") and
    has("last_started_at") and
    has("last_finished_at") and
    has("next_attempt_at") and
    (.status | type == "string") and
    (.attempt_count | type == "number" and . >= 0 and floor == .) and
    (.last_exit_code | . == null or type == "number") and
    (.last_classification | . == null or type == "string") and
    (.last_started_at | . == null or type == "string") and
    (.last_finished_at | . == null or type == "string") and
    (.next_attempt_at | . == null or type == "string") and
    (.defer_count | . == null or (type == "number" and . >= 0 and floor == .)) and
    (.last_deferred_at | . == null or type == "string")
  ' >/dev/null
)

schedule_resume_create_job() (
  manifest=$1
  _schedule_resume_validate_manifest "$manifest" || return 1

  job_id=$(printf '%s\n' "$manifest" | jq -r '.job_id') || return 1
  schedule_resume_validate_job_id "$job_id" >/dev/null || return 1

  status=$(printf '%s\n' "$manifest" | jq -r '.status') || return 1
  _schedule_resume_is_approved_status "$status" || return 1

  job_dir=$(schedule_resume_job_dir "$job_id") || return 1
  manifest_path=$(schedule_resume_manifest_path "$job_id") || return 1
  status_path=$(schedule_resume_status_path "$job_id") || return 1
  (umask 077; mkdir -p "$RESUME_JOB_STATE_ROOT" && chmod 700 "$RESUME_JOB_STATE_ROOT") || return 1
  (umask 077; mkdir -m 700 "$job_dir") 2>/dev/null || return 1

  first_attempt_at=$(printf '%s\n' "$manifest" | jq -r '.first_attempt_at') || return 1
  initial_status=$(jq -n \
    --arg status "$status" \
    --arg next_attempt_at "$first_attempt_at" \
    '{
      status: $status,
      attempt_count: 0,
      last_exit_code: null,
      last_classification: null,
      last_started_at: null,
      last_finished_at: null,
      next_attempt_at: $next_attempt_at
    }') || return 1

  if ! _schedule_resume_atomic_write_json "$manifest_path" "$manifest" ||
    ! _schedule_resume_atomic_write_json "$status_path" "$initial_status"; then
    rm -f "$manifest_path" "$status_path"
    rmdir "$job_dir" 2>/dev/null
    return 1
  fi
)

schedule_resume_write_status() (
  job_id=$1
  status_json=$2
  schedule_resume_validate_job_id "$job_id" >/dev/null || return 1
  _schedule_resume_validate_status_json "$status_json" || return 1

  status=$(printf '%s\n' "$status_json" | jq -r '.status') || return 1
  _schedule_resume_is_approved_status "$status" || return 1

  status_path=$(schedule_resume_status_path "$job_id") || return 1
  [ -f "$(schedule_resume_manifest_path "$job_id")" ] || return 1
  _schedule_resume_atomic_write_json "$status_path" "$status_json"
)

schedule_resume_read_status() (
  status_path=$(schedule_resume_status_path "${1-}") || return 1
  [ -f "$status_path" ] || return 1

  status=$(jq -er '.status | select(type == "string")' "$status_path") || return 1
  _schedule_resume_is_approved_status "$status" || return 1
  printf '%s\n' "$status"
)

schedule_resume_read_manifest() (
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  manifest_path=$(schedule_resume_manifest_path "$job_id") || return 1
  [ -f "$manifest_path" ] || return 1

  manifest=$(jq -c . "$manifest_path") || return 1
  _schedule_resume_validate_manifest "$manifest" || return 1
  [ "$(printf '%s\n' "$manifest" | jq -r '.job_id')" = "$job_id" ] || return 1
  printf '%s\n' "$manifest"
)

_schedule_resume_timestamp_now() (
  date -u '+%Y-%m-%dT%H:%M:%SZ'
)

_schedule_resume_timestamp_after() (
  seconds=$1
  epoch=$(( $(date +%s) + seconds ))
  date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%SZ'
)

_schedule_resume_attempt_exit_cleanup() (
  job_id=$1
  job_dir=$2
  owner_pid=$3
  running_published=$4
  attempt_finalized=$5
  running_status=$6
  started_at=$7
  last_exit_code=$8

  if [ "$running_published" -eq 1 ] && [ "$attempt_finalized" -ne 1 ]; then
    persisted_status=$(jq -c . "$job_dir/status.json" 2>/dev/null) || persisted_status=
    persisted_state=$(printf '%s\n' "$persisted_status" | jq -r '.status // empty' 2>/dev/null) || persisted_state=
    persisted_attempt_count=$(printf '%s\n' "$persisted_status" | jq -r '.attempt_count // empty' 2>/dev/null) || persisted_attempt_count=
    running_attempt_count=$(printf '%s\n' "$running_status" | jq -r '.attempt_count // empty' 2>/dev/null) || running_attempt_count=
    if [ "$persisted_state" = running ] &&
      [ -n "$persisted_attempt_count" ] &&
      [ "$persisted_attempt_count" = "$running_attempt_count" ]; then
      finished_at=$(_schedule_resume_timestamp_now 2>/dev/null) || finished_at=$started_at
      failure_status=$(printf '%s\n' "$running_status" | jq -c \
        --argjson exit_code "$last_exit_code" \
        --arg finished_at "$finished_at" \
        '.status = "failed" |
          .last_exit_code = $exit_code |
          .last_classification = "failure_terminal" |
          .last_finished_at = $finished_at |
          .next_attempt_at = null' 2>/dev/null) || failure_status=
      [ -z "$failure_status" ] || schedule_resume_write_status "$job_id" "$failure_status" >/dev/null 2>&1 || :
    fi
  fi
  schedule_resume_release_lock "$job_dir" "$owner_pid" >/dev/null 2>&1 || :
)

schedule_resume_run_attempt() (
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  manifest=$(schedule_resume_read_manifest "$job_id") || return 1
  job_dir=$(schedule_resume_job_dir "$job_id") || return 1
  retry_interval_seconds=$(printf '%s\n' "$manifest" | jq -r '.retry_interval_seconds') || return 1
  _schedule_resume_timestamp_after "$retry_interval_seconds" >/dev/null || return 1

  runner_pid_file=$(mktemp "$job_dir/.runner-pid.XXXXXX") || return 1
  if ! sh -c 'printf "%s\n" "$PPID"' >"$runner_pid_file"; then
    rm -f "$runner_pid_file"
    return 1
  fi
  runner_pid=
  IFS= read -r runner_pid <"$runner_pid_file" || :
  rm -f "$runner_pid_file"
  _schedule_resume_lock_pid_is_valid "$runner_pid" || return 1

  if schedule_resume_acquire_lock "$job_dir" "$runner_pid"; then
    :
  else
    lock_result=$?
    [ "$lock_result" -eq 75 ] && return 0
    return "$lock_result"
  fi

  running_published=0
  attempt_finalized=0
  running_status=
  started_at=
  last_exit_code=null
  trap '_schedule_resume_attempt_exit_cleanup "$job_id" "$job_dir" "$runner_pid" "$running_published" "$attempt_finalized" "$running_status" "$started_at" "$last_exit_code"' 0
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  current_status=$(jq -c . "$job_dir/status.json") || return 1
  _schedule_resume_validate_status_json "$current_status" || return 1
  locked_status=$(printf '%s\n' "$current_status" | jq -r '.status') || return 1
  case "$locked_status" in
    completed | failed | cancelled)
      return 0
      ;;
  esac

  target_harness=$(printf '%s\n' "$manifest" | jq -r '.target_harness') || return 1
  harness_executable=$(printf '%s\n' "$manifest" | jq -r '.harness_executable') || return 1
  session_id=$(printf '%s\n' "$manifest" | jq -r '.session_id') || return 1
  project_dir=$(printf '%s\n' "$manifest" | jq -r '.project_dir') || return 1
  prompt_file=$(printf '%s\n' "$manifest" | jq -r '.prompt_file') || return 1
  completion_policy=$(printf '%s\n' "$manifest" | jq -r '.completion_policy') || return 1

  # Liveness guard: never resume a session that is currently being worked, or
  # its transcript would be corrupted by two concurrent agents. A deferral is
  # not an attempt (attempt_count untouched); it just re-arms the next poll.
  liveness=$(schedule_resume_session_liveness "$target_harness" "$session_id") || liveness=absent
  if [ "$liveness" = active ]; then
    deferred_at=$(_schedule_resume_timestamp_now) || return 1
    deferred_next=$(_schedule_resume_timestamp_after "$retry_interval_seconds") || return 1
    deferred_status=$(printf '%s\n' "$current_status" | jq -c \
      --arg deferred_at "$deferred_at" \
      --arg next_attempt_at "$deferred_next" \
      '.status = "scheduled" |
        .last_classification = "deferred_session_active" |
        .defer_count = ((.defer_count // 0) + 1) |
        .last_deferred_at = $deferred_at |
        .next_attempt_at = $next_attempt_at') || return 1
    schedule_resume_write_status "$job_id" "$deferred_status" || return 1
    return 0
  fi

  attempt_count=$(( $(printf '%s\n' "$current_status" | jq -r '.attempt_count') + 1 ))
  started_at=$(_schedule_resume_timestamp_now) || return 1
  running_status=$(printf '%s\n' "$current_status" | jq -c \
    --arg started_at "$started_at" \
    --argjson attempt_count "$attempt_count" \
    '.status = "running" |
      .attempt_count = $attempt_count |
      .last_exit_code = null |
      .last_classification = null |
      .last_started_at = $started_at |
      .last_finished_at = null |
      .next_attempt_at = null') || return 1

  running_published=1
  schedule_resume_write_status "$job_id" "$running_status" || return 1

  attempts_dir=$job_dir/attempts
  attempt_dir=$attempts_dir/$attempt_count
  (umask 077; mkdir -p "$attempts_dir" && chmod 700 "$attempts_dir") || return 1
  (umask 077; mkdir -m 700 "$attempt_dir") || return 1
  stdout_file=$attempt_dir/stdout.log
  stderr_file=$attempt_dir/stderr.log

  if schedule_resume_execute_target "$target_harness" "$harness_executable" "$session_id" "$project_dir" "$prompt_file" >"$stdout_file" 2>"$stderr_file"; then
    exit_code=0
  else
    exit_code=$?
  fi
  last_exit_code=$exit_code

  classification=$(classify_result "$exit_code" "$completion_policy" "$stdout_file" "$stderr_file") || return 1
  finished_at=$(_schedule_resume_timestamp_now) || return 1

  case "$classification" in
    success)
      final_status=completed
      next_attempt_at=null
      ;;
    quota_retryable | availability_retryable | transient_retryable | incomplete_retryable)
      final_status=retrying
      next_attempt_at=$(_schedule_resume_timestamp_after "$retry_interval_seconds") || return 1
      ;;
    *)
      final_status=failed
      next_attempt_at=null
      ;;
  esac

  if [ "$next_attempt_at" = null ]; then
    final_status_json=$(printf '%s\n' "$running_status" | jq -c \
      --arg status "$final_status" \
      --argjson exit_code "$exit_code" \
      --arg classification "$classification" \
      --arg finished_at "$finished_at" \
      '.status = $status |
        .last_exit_code = $exit_code |
        .last_classification = $classification |
        .last_finished_at = $finished_at |
        .next_attempt_at = null') || return 1
  else
    final_status_json=$(printf '%s\n' "$running_status" | jq -c \
      --arg status "$final_status" \
      --argjson exit_code "$exit_code" \
      --arg classification "$classification" \
      --arg finished_at "$finished_at" \
      --arg next_attempt_at "$next_attempt_at" \
      '.status = $status |
        .last_exit_code = $exit_code |
        .last_classification = $classification |
        .last_finished_at = $finished_at |
        .next_attempt_at = $next_attempt_at') || return 1
  fi

  schedule_resume_write_status "$job_id" "$final_status_json" || return 1
  attempt_finalized=1
)
