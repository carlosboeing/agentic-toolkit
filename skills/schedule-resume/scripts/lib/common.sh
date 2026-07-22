#!/bin/sh

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
