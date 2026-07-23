#!/bin/sh
set -eu
umask 077

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
: "${RESUME_JOB_STATE_ROOT:=$HOME/.local/state/resume-job}"
export RESUME_JOB_STATE_ROOT

. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/state.sh"
. "$SCRIPT_DIR/lib/lock.sh"
. "$SCRIPT_DIR/lib/adapters.sh"
. "$SCRIPT_DIR/lib/scheduler-cron.sh"

resolve_harness_executable() {
  harness_name=$1
  harness_candidate=$(command -v "$harness_name") || return 1
  case "$harness_candidate" in /*) ;; *) return 1 ;; esac
  [ -f "$harness_candidate" ] && [ -x "$harness_candidate" ] || return 1
  harness_dir=$(CDPATH='' cd -- "${harness_candidate%/*}" && pwd) || return 1
  printf '%s/%s\n' "$harness_dir" "${harness_candidate##*/}"
}

usage() {
  printf '%s\n' \
    'usage: resume-job.sh create --target-harness H --session-id ID --project-dir DIR --prompt-file FILE --schedule-type TYPE --first-attempt-at UTC_ISO_WITH_00_SECONDS --retry-interval-seconds N --retry-policy POLICY --completion-policy POLICY --permissions-mode MODE [--job-id ID]' \
    '       resume-job.sh list' \
    '       resume-job.sh status JOB_ID' \
    '       resume-job.sh cancel JOB_ID' \
    '       resume-job.sh run JOB_ID' \
    '       resume-job.sh cleanup RETENTION_DAYS  # decimal integer 0..36500' \
    '       resume-job.sh doctor' >&2
}

require_value() {
  [ "$#" -ge 2 ] && [ -n "$2" ] || {
    usage
    exit 2
  }
}

set_current_process_pid() {
  schedule_resume_pid_file=$(mktemp "${TMPDIR:-/tmp}/schedule-resume-pid.XXXXXX") || return 1
  if ! sh -c 'printf "%s\n" "$PPID"' >"$schedule_resume_pid_file"; then
    rm -f "$schedule_resume_pid_file"
    return 1
  fi
  SCHEDULE_RESUME_CURRENT_PROCESS_PID=
  IFS= read -r SCHEDULE_RESUME_CURRENT_PROCESS_PID <"$schedule_resume_pid_file" || :
  rm -f "$schedule_resume_pid_file"
  _schedule_resume_lock_pid_is_valid "$SCHEDULE_RESUME_CURRENT_PROCESS_PID"
}

write_wrapper() {
  wrapper_job_id=$1
  wrapper_path=$2
  wrapper_cli=$3
  wrapper_root=$4
  escaped_cli=$(printf '%s' "$wrapper_cli" | sed "s/'/'\\\\''/g") || return 1
  escaped_root=$(printf '%s' "$wrapper_root" | sed "s/'/'\\\\''/g") || return 1
  escaped_path=$(printf '%s' "${PATH:-/usr/bin:/bin}" | sed "s/'/'\\\\''/g") || return 1
  escaped_log=$(printf '%s' "$wrapper_root/$wrapper_job_id/cron.log" | sed "s/'/'\\\\''/g") || return 1
  temporary=$(mktemp "${wrapper_path%/*}/.wrapper.XXXXXX") || return 1
  if ! printf '%s\n' '#!/bin/sh' 'umask 077' "PATH='$escaped_path'" 'export PATH' "RESUME_JOB_STATE_ROOT='$escaped_root'" 'export RESUME_JOB_STATE_ROOT' "exec '$escaped_cli' run '$wrapper_job_id' >>'$escaped_log' 2>&1" >"$temporary" ||
    ! chmod 700 "$temporary" || ! mv "$temporary" "$wrapper_path"; then
    rm -f "$temporary"
    return 1
  fi
}

create_job() {
  target_harness=
  session_id=
  project_dir=
  prompt_file=
  schedule_type=
  first_attempt_at=
  retry_interval_seconds=
  retry_policy=
  completion_policy=
  permissions_mode=
  job_id=

  while [ "$#" -gt 0 ]; do
    require_value "$@"
    option=$1
    value=$2
    shift 2
    case "$option" in
      --target-harness) [ -z "$target_harness" ] || exit 2; target_harness=$value ;;
      --session-id) [ -z "$session_id" ] || exit 2; session_id=$value ;;
      --project-dir) [ -z "$project_dir" ] || exit 2; project_dir=$value ;;
      --prompt-file) [ -z "$prompt_file" ] || exit 2; prompt_file=$value ;;
      --schedule-type) [ -z "$schedule_type" ] || exit 2; schedule_type=$value ;;
      --first-attempt-at) [ -z "$first_attempt_at" ] || exit 2; first_attempt_at=$value ;;
      --retry-interval-seconds) [ -z "$retry_interval_seconds" ] || exit 2; retry_interval_seconds=$value ;;
      --retry-policy) [ -z "$retry_policy" ] || exit 2; retry_policy=$value ;;
      --completion-policy) [ -z "$completion_policy" ] || exit 2; completion_policy=$value ;;
      --permissions-mode) [ -z "$permissions_mode" ] || exit 2; permissions_mode=$value ;;
      --job-id) [ -z "$job_id" ] || exit 2; job_id=$value ;;
      *) usage; exit 2 ;;
    esac
  done

  [ -n "$target_harness" ] && [ -n "$session_id" ] && [ -n "$project_dir" ] &&
    [ -n "$prompt_file" ] && [ -n "$schedule_type" ] && [ -n "$first_attempt_at" ] &&
    [ -n "$retry_interval_seconds" ] && [ -n "$retry_policy" ] &&
    [ -n "$completion_policy" ] && [ -n "$permissions_mode" ] || {
      usage
      return 2
    }
  case "$target_harness" in claude | agy | codex) ;; *) return 2 ;; esac
  case "$schedule_type" in calendar | reset) ;; *) return 2 ;; esac
  [ "$retry_policy" = until-completed ] || return 2
  case "$completion_policy" in session-exits-zero | sentinel-output) ;; *) return 2 ;; esac
  [ "$permissions_mode" = full-auto ] || return 2
  case "$retry_interval_seconds" in '' | *[!0-9]*) return 2 ;; esac
  [ "$retry_interval_seconds" -gt 0 ] || return 2
  _schedule_resume_timestamp_epoch "$first_attempt_at" >/dev/null || return 2
  case "$first_attempt_at" in *:??:00Z) ;; *) return 2 ;; esac
  [ -d "$project_dir" ] && [ -f "$prompt_file" ] && [ -r "$prompt_file" ] || return 2
  harness_executable=$(resolve_harness_executable "$target_harness") || return 2
  project_dir=$(CDPATH='' cd -- "$project_dir" && pwd) || return 2
  case "$prompt_file" in
    */*) prompt_parent_input=${prompt_file%/*} ;;
    *) prompt_parent_input=. ;;
  esac
  prompt_parent=$(CDPATH='' cd -- "$prompt_parent_input" && pwd) || return 2
  prompt_file="$prompt_parent/${prompt_file##*/}"
  for _fda_path in "$project_dir" "$prompt_file" "$RESUME_JOB_STATE_ROOT"; do
    if schedule_resume_tcc_protected_path "$_fda_path"; then
      printf 'warning: %s is under a macOS Full-Disk-Access-protected folder; cron may be denied access and the job could silently never run. Grant /usr/sbin/cron Full Disk Access in System Settings > Privacy & Security if it never fires.\n' "$_fda_path" >&2
    fi
  done
  if [ -z "$job_id" ]; then
    job_id="job-$(date -u '+%Y%m%dT%H%M%SZ')-$$"
  fi
  schedule_resume_validate_job_id "$job_id" >/dev/null || return 2

  job_dir=$(schedule_resume_job_dir "$job_id") || return 1
  owned_prompt="$job_dir/prompt.txt"
  created_at=$(_schedule_resume_timestamp_now) || return 1
  manifest=$(jq -cn \
    --arg job_id "$job_id" \
    --arg target_harness "$target_harness" \
    --arg harness_executable "$harness_executable" \
    --arg session_id "$session_id" \
    --arg project_dir "$project_dir" \
    --arg prompt_file "$owned_prompt" \
    --arg schedule_type "$schedule_type" \
    --arg first_attempt_at "$first_attempt_at" \
    --argjson retry_interval_seconds "$retry_interval_seconds" \
    --arg retry_policy "$retry_policy" \
    --arg completion_policy "$completion_policy" \
    --arg permissions_mode "$permissions_mode" \
    --arg created_at "$created_at" \
    '{job_id: $job_id, target_harness: $target_harness, harness_executable: $harness_executable, session_id: $session_id,
      project_dir: $project_dir, prompt_file: $prompt_file, schedule_type: $schedule_type,
      first_attempt_at: $first_attempt_at, retry_interval_seconds: $retry_interval_seconds,
      retry_policy: $retry_policy, completion_policy: $completion_policy,
      permissions_mode: $permissions_mode, created_at: $created_at, status: "scheduled"}') || return 1

  schedule_resume_create_job "$manifest" || return 1
  created=1
  rollback() {
    if [ "${created:-0}" -eq 1 ]; then
      schedule_resume_scheduler_remove "$job_id" >/dev/null 2>&1 || :
      rm -rf "$job_dir"
    fi
  }
  trap 'rollback' 0 HUP INT TERM

  prompt_temporary=$(mktemp "$job_dir/.prompt.XXXXXX") || return 1
  if ! cp "$prompt_file" "$prompt_temporary" || ! chmod 600 "$prompt_temporary" || ! mv "$prompt_temporary" "$owned_prompt"; then
    rm -f "$prompt_temporary"
    return 1
  fi
  wrapper="$job_dir/run.sh"
  write_wrapper "$job_id" "$wrapper" "$SCRIPT_DIR/resume-job.sh" "$RESUME_JOB_STATE_ROOT" || return 1
  schedule_resume_scheduler_reconcile >/dev/null 2>&1 || :
  schedule_resume_scheduler_install "$job_id" "$wrapper" || return 1
  created=0
  trap - 0 HUP INT TERM
  printf '%s\n' "$job_id"
}

list_jobs() {
  [ -d "$RESUME_JOB_STATE_ROOT" ] || return 0
  for candidate in "$RESUME_JOB_STATE_ROOT"/*; do
    [ -d "$candidate" ] && [ ! -L "$candidate" ] || continue
    candidate_id=${candidate##*/}
    schedule_resume_validate_job_id "$candidate_id" >/dev/null 2>&1 || continue
    schedule_resume_read_manifest "$candidate_id" >/dev/null 2>&1 || continue
    schedule_resume_read_status "$candidate_id" >/dev/null 2>&1 || continue
    printf '%s\n' "$candidate_id"
  done
}

status_job() {
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 2
  [ "$#" -eq 1 ] || return 2
  manifest=$(schedule_resume_read_manifest "$job_id") || return 1
  status_path=$(schedule_resume_status_path "$job_id") || return 1
  status_json=$(jq -c . "$status_path") || return 1
  _schedule_resume_validate_status_json "$status_json" || return 1
  jq '.' "$status_path"
}

cancel_job() (
  [ "$#" -eq 1 ] || return 2
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 2
  schedule_resume_read_manifest "$job_id" >/dev/null || return 1
  job_dir=$(schedule_resume_job_dir "$job_id") || return 1
  status_path=$(schedule_resume_status_path "$job_id") || return 1
  current=$(jq -c . "$status_path") || return 1
  _schedule_resume_validate_status_json "$current" || return 1
  schedule_resume_scheduler_reconcile >/dev/null 2>&1 || :
  schedule_resume_scheduler_remove "$job_id" || return 1

  cancel_lock_timeout=${RESUME_JOB_CANCEL_LOCK_TIMEOUT_SECONDS:-10}
  case "$cancel_lock_timeout" in '' | *[!0-9]*) return 1 ;; esac
  cancel_lock_deadline=$(( $(date +%s) + cancel_lock_timeout ))
  set_current_process_pid || return 1
  cancel_pid=$SCHEDULE_RESUME_CURRENT_PROCESS_PID
  cancel_lock_acquired=0
  while :; do
    if schedule_resume_acquire_lock "$job_dir" "$cancel_pid"; then
      cancel_lock_acquired=1
      break
    else
      cancel_lock_result=$?
    fi
    if [ "$cancel_lock_result" -ne 75 ]; then
      return "$cancel_lock_result"
    fi
    if [ "$(date +%s)" -ge "$cancel_lock_deadline" ]; then
      printf 'cannot cancel job %s: attempt lock remains held after removing the cron entry; retry after the current runner exits\n' "$job_id" >&2
      return 75
    fi
    /bin/sleep 0.05
  done
  trap 'if [ "$cancel_lock_acquired" -eq 1 ]; then schedule_resume_release_lock "$job_dir" "$cancel_pid" >/dev/null 2>&1 || :; fi' 0
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  current=$(jq -c . "$status_path") || return 1
  _schedule_resume_validate_status_json "$current" || return 1
  finished_at=$(_schedule_resume_timestamp_now) || return 1
  cancelled=$(printf '%s\n' "$current" | jq -c --arg finished_at "$finished_at" \
    '.status = "cancelled" |
      .last_classification = (.last_classification // "cancelled") |
      .last_finished_at = (.last_finished_at // $finished_at) |
      .next_attempt_at = null') || return 1
  schedule_resume_write_status "$job_id" "$cancelled" || return 1
  schedule_resume_release_lock "$job_dir" "$cancel_pid" || return 1
  cancel_lock_acquired=0
)

run_job() {
  [ "$#" -eq 1 ] || return 2
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 2
  status_path=$(schedule_resume_status_path "$job_id") || return 1
  status_json=$(jq -c . "$status_path") || return 1
  _schedule_resume_validate_status_json "$status_json" || return 1
  state=$(printf '%s\n' "$status_json" | jq -r '.status') || return 1
  case "$state" in
    completed | failed | cancelled)
      schedule_resume_scheduler_remove "$job_id" >/dev/null 2>&1 || :
      return 0
      ;;
  esac
  next_attempt_at=$(printf '%s\n' "$status_json" | jq -r '.next_attempt_at // empty') || return 1
  if [ -n "$next_attempt_at" ]; then
    due_epoch=$(_schedule_resume_timestamp_epoch "$next_attempt_at") || return 1
    now_epoch=$(date +%s) || return 1
    [ "$now_epoch" -ge "$due_epoch" ] || return 0
  fi
  if schedule_resume_run_attempt "$job_id"; then
    run_attempt_result=0
  else
    run_attempt_result=$?
  fi
  post_state=$(jq -r '.status // empty' "$status_path" 2>/dev/null) || post_state=
  case "$post_state" in
    completed | failed | cancelled)
      schedule_resume_scheduler_remove "$job_id" >/dev/null 2>&1 || :
      ;;
  esac
  return "$run_attempt_result"
}

cleanup_jobs() {
  [ "$#" -eq 1 ] || return 2
  retention_days=$1
  case "$retention_days" in
    '' | *[!0-9]*)
      printf 'RETENTION_DAYS must be a decimal integer from 0 through 36500\n' >&2
      return 2
      ;;
  esac
  while [ "$retention_days" != 0 ] && [ "${retention_days#0}" != "$retention_days" ]; do
    retention_days=${retention_days#0}
  done
  if [ "${#retention_days}" -gt 5 ] || [ "$retention_days" -gt 36500 ]; then
    printf 'RETENTION_DAYS must be a decimal integer from 0 through 36500\n' >&2
    return 2
  fi
  now_epoch=$(date +%s) || return 1
  cutoff=$((now_epoch - retention_days * 86400))
  [ -d "$RESUME_JOB_STATE_ROOT" ] || return 0
  cleanup_root=$(CDPATH='' cd -- "$RESUME_JOB_STATE_ROOT" && pwd -P) || return 1
  RESUME_JOB_STATE_ROOT=$cleanup_root
  export RESUME_JOB_STATE_ROOT
  set_current_process_pid || return 1
  cleanup_pid=$SCHEDULE_RESUME_CURRENT_PROCESS_PID
  schedule_resume_scheduler_reconcile >/dev/null 2>&1 || :
  for candidate in "$cleanup_root"/*; do
    [ -d "$candidate" ] && [ ! -L "$candidate" ] || continue
    job_id=${candidate##*/}
    schedule_resume_validate_job_id "$job_id" >/dev/null 2>&1 || continue
    [ "$candidate" = "$cleanup_root/$job_id" ] || continue
    schedule_resume_read_manifest "$job_id" >/dev/null 2>&1 || continue
    cleanup_pre_status=$(jq -c . "$candidate/status.json" 2>/dev/null) || continue
    _schedule_resume_validate_status_json "$cleanup_pre_status" || continue
    schedule_resume_read_status "$job_id" >/dev/null 2>&1 || continue

    if schedule_resume_acquire_lock "$candidate" "$cleanup_pid"; then
      :
    else
      cleanup_lock_result=$?
      if [ "$cleanup_lock_result" -eq 75 ]; then
        printf 'cleanup skipped job %s: lock is held\n' "$job_id" >&2
        continue
      fi
      return "$cleanup_lock_result"
    fi

    if ! schedule_resume_read_manifest "$job_id" >/dev/null 2>&1; then
      schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
      continue
    fi
    status_json=$(jq -c . "$candidate/status.json" 2>/dev/null) || {
      schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
      continue
    }
    if ! _schedule_resume_validate_status_json "$status_json"; then
      schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
      continue
    fi
    state=$(printf '%s\n' "$status_json" | jq -r '.status') || {
      schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
      continue
    }
    case "$state" in
      completed | failed | cancelled) ;;
      *)
        schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
        continue
        ;;
    esac
    finished_at=$(printf '%s\n' "$status_json" | jq -r '.last_finished_at // empty') || {
      schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
      continue
    }
    if [ -z "$finished_at" ]; then
      schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
      continue
    fi
    finished_epoch=$(_schedule_resume_timestamp_epoch "$finished_at") || {
      schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
      continue
    }
    if [ "$finished_epoch" -gt "$cutoff" ]; then
      schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
      continue
    fi
    if schedule_resume_scheduler_remove "$job_id"; then
      :
    else
      cleanup_remove_result=$?
      schedule_resume_release_lock "$candidate" "$cleanup_pid" || return 1
      return "$cleanup_remove_result"
    fi
    rm -rf "$candidate" || {
      schedule_resume_release_lock "$candidate" "$cleanup_pid" >/dev/null 2>&1 || :
      return 1
    }
  done
}

doctor_jobs() {
  printf 'schedule-resume cron entries:\n'
  crontab -l 2>/dev/null | while IFS= read -r doctor_line || [ -n "$doctor_line" ]; do
    case "$doctor_line" in
      *"# schedule-resume:"*)
        doctor_jid=${doctor_line##*# schedule-resume:}
        if schedule_resume_validate_job_id "$doctor_jid" >/dev/null 2>&1 &&
          [ -d "$(schedule_resume_job_dir "$doctor_jid" 2>/dev/null)" ]; then
          doctor_state=$(schedule_resume_read_status "$doctor_jid" 2>/dev/null) || doctor_state=unknown
          printf '  %s  [live: %s]\n' "$doctor_jid" "$doctor_state"
        else
          printf '  %s  [ORPHAN: no job directory]\n' "$doctor_jid"
        fi
        ;;
    esac
  done
  schedule_resume_scheduler_reconcile >/dev/null 2>&1 || :
  doctor_leftover=$(ls "$HOME"/Library/LaunchAgents/com.carlos.resume-job.*.plist 2>/dev/null) || doctor_leftover=
  if [ -n "$doctor_leftover" ]; then
    printf '\nLeftover launchd agents from the old backend were found. Remove them with:\n'
    # shellcheck disable=SC2016  # deliberately printed verbatim for the user to run
    printf '  for p in "$HOME"/Library/LaunchAgents/com.carlos.resume-job.*.plist; do [ -e "$p" ] || continue; launchctl bootout "gui/$(id -u)/$(basename "$p" .plist)" 2>/dev/null; rm -f "$p"; done\n'
  fi
  printf '\nTo purge every schedule-resume cron entry:\n'
  printf "  crontab -l | grep -v '# schedule-resume:' | crontab -\n"
}

command=${1-}
[ -n "$command" ] || { usage; exit 2; }
shift
case "$command" in
  create) create_job "$@" ;;
  list) [ "$#" -eq 0 ] || { usage; exit 2; }; list_jobs ;;
  status) status_job "$@" ;;
  cancel) cancel_job "$@" ;;
  run) run_job "$@" ;;
  cleanup) cleanup_jobs "$@" ;;
  doctor) [ "$#" -eq 0 ] || { usage; exit 2; }; doctor_jobs ;;
  *) usage; exit 2 ;;
esac
