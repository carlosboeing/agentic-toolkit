#!/bin/sh

: "${SCHEDULE_RESUME_SENTINEL:=SCHEDULE_RESUME_TASK_COMPLETE}"

# Poll cadence shared by both scheduler backends: cron's `* * * * *` fires every
# 60 seconds; the launchd StartInterval must match so due-gating behaves the same.
: "${SCHEDULE_RESUME_POLL_INTERVAL_SECONDS:=60}"

schedule_resume_validate_job_id() (
  job_id=${1-}

  case "$job_id" in
    "" | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*)
      return 1
      ;;
  esac

  printf '%s\n' "$job_id"
)

schedule_resume_job_dir() (
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  : "${RESUME_JOB_STATE_ROOT:?RESUME_JOB_STATE_ROOT must be set}"
  printf '%s/%s\n' "${RESUME_JOB_STATE_ROOT%/}" "$job_id"
)

schedule_resume_manifest_path() (
  job_dir=$(schedule_resume_job_dir "${1-}") || return 1
  printf '%s/manifest.json\n' "$job_dir"
)

schedule_resume_status_path() (
  job_dir=$(schedule_resume_job_dir "${1-}") || return 1
  printf '%s/status.json\n' "$job_dir"
)

_schedule_resume_atomic_write_json() (
  destination=$1
  json=$2
  directory=${destination%/*}
  temporary=$(mktemp "$directory/.schedule-resume.XXXXXX") || return 1

  if ! printf '%s\n' "$json" | jq '.' >"$temporary"; then
    rm -f "$temporary"
    return 1
  fi

  if ! mv "$temporary" "$destination"; then
    rm -f "$temporary"
    return 1
  fi
)

# Parse a strict UTC ISO timestamp (YYYY-MM-DDTHH:MM:SSZ) to epoch seconds.
# The round-trip re-format rejects impossible dates (e.g. month 13) that BSD
# date would otherwise normalize. The `date -j` form is macOS-only; the GNU
# equivalent (`date -u -d`) is the documented Linux portability gap.
_schedule_resume_timestamp_epoch() (
  timestamp=${1-}
  case "$timestamp" in
    ????-??-??T??:??:??Z) ;;
    *) return 1 ;;
  esac

  epoch=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$timestamp" '+%s' 2>/dev/null) || return 1
  [ "$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$timestamp" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)" = "$timestamp" ] || return 1
  printf '%s\n' "$epoch"
)

# True when the job's status.json exists and records a terminal state.
schedule_resume_job_is_terminal() (
  status_path=$(schedule_resume_status_path "${1-}") || return 1
  [ -f "$status_path" ] || return 1
  state=$(jq -r '.status // empty' "$status_path" 2>/dev/null) || return 1
  case "$state" in
    completed | failed | cancelled) return 0 ;;
  esac
  return 1
)

# True when the path sits under a macOS folder protected by TCC, which a
# background scheduler process cannot read without a user grant.
schedule_resume_tcc_protected_path() (
  case "$(uname -s 2>/dev/null)" in Darwin) ;; *) return 1 ;; esac
  _tcc_path=${1-}
  [ -n "$_tcc_path" ] || return 1
  _tcc_home=${HOME%/}
  case "$_tcc_path" in
    "$_tcc_home"/Documents | "$_tcc_home"/Documents/* \
    | "$_tcc_home"/Desktop | "$_tcc_home"/Desktop/* \
    | "$_tcc_home"/Downloads | "$_tcc_home"/Downloads/* \
    | "$_tcc_home"/Library/Mobile\ Documents | "$_tcc_home"/Library/Mobile\ Documents/*)
      return 0
      ;;
  esac
  return 1
)
