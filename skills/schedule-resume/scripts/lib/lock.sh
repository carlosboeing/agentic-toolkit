#!/bin/sh

_schedule_resume_lock_pid_is_valid() (
  case "${1-}" in
    "" | *[!0-9]*)
      return 1
      ;;
    *)
      [ "$1" -gt 0 ] 2>/dev/null
      ;;
  esac
)

_schedule_resume_require_lockf() (
  _schedule_resume_lockf=$1
  if [ ! -x "$_schedule_resume_lockf" ]; then
    printf 'schedule-resume requires executable macOS lockf at %s for safe job locking\n' "$_schedule_resume_lockf" >&2
    return 1
  fi
)

_schedule_resume_remove_stale_main_lock() (
  _schedule_resume_lock_dir=$1

  rm -f "$_schedule_resume_lock_dir/pid" "$_schedule_resume_lock_dir/started_at" || return 1
  for _schedule_resume_lock_temporary in "$_schedule_resume_lock_dir"/.pid.*; do
    [ -e "$_schedule_resume_lock_temporary" ] || continue
    rm -f "$_schedule_resume_lock_temporary" || return 1
  done
  rmdir "$_schedule_resume_lock_dir" 2>/dev/null
)

schedule_resume_acquire_lock() (
  _schedule_resume_lock_job_dir=$1
  _schedule_resume_lock_pid=$2
  _schedule_resume_lock_dir=$_schedule_resume_lock_job_dir/lock
  _schedule_resume_guard_file=$_schedule_resume_lock_job_dir/.lock-guard
  _schedule_resume_lockf=${RESUME_JOB_LOCKF:-/usr/bin/lockf}
  _schedule_resume_lock_pid_is_valid "$_schedule_resume_lock_pid" || return 1

  _schedule_resume_require_lockf "$_schedule_resume_lockf" || return 1
  exec 9>>"$_schedule_resume_guard_file" || {
    printf 'cannot open schedule-resume lock guard: %s\n' "$_schedule_resume_guard_file" >&2
    return 1
  }
  if "$_schedule_resume_lockf" -s -t 0 9; then
    :
  else
    _schedule_resume_lockf_result=$?
    [ "$_schedule_resume_lockf_result" -eq 75 ] && return 75
    printf 'schedule-resume lockf acquisition failed with exit %s for %s\n' \
      "$_schedule_resume_lockf_result" "$_schedule_resume_guard_file" >&2
    return "$_schedule_resume_lockf_result"
  fi

  if [ -e "$_schedule_resume_lock_dir" ]; then
    _schedule_resume_existing_pid=
    if [ -f "$_schedule_resume_lock_dir/pid" ]; then
      IFS= read -r _schedule_resume_existing_pid <"$_schedule_resume_lock_dir/pid" || :
    fi
    if _schedule_resume_lock_pid_is_valid "$_schedule_resume_existing_pid" &&
      kill -0 "$_schedule_resume_existing_pid" 2>/dev/null; then
      return 75
    fi

    # Every publisher holds lockf until PID metadata is visible. Therefore a
    # PID-less directory observed under this guard is abandoned and recoverable.
    _schedule_resume_remove_stale_main_lock "$_schedule_resume_lock_dir" || return 1
  fi

  mkdir "$_schedule_resume_lock_dir" 2>/dev/null || return 1
  _schedule_resume_lock_pid_temporary=$_schedule_resume_lock_dir/.pid.$_schedule_resume_lock_pid
  if ! printf '%s\n' "$_schedule_resume_lock_pid" >"$_schedule_resume_lock_pid_temporary" ||
    ! mv "$_schedule_resume_lock_pid_temporary" "$_schedule_resume_lock_dir/pid" ||
    ! date '+%Y-%m-%dT%H:%M:%S%z' >"$_schedule_resume_lock_dir/started_at"; then
    rm -f "$_schedule_resume_lock_pid_temporary" "$_schedule_resume_lock_dir/pid" "$_schedule_resume_lock_dir/started_at"
    rmdir "$_schedule_resume_lock_dir" 2>/dev/null
    return 1
  fi
)

schedule_resume_release_lock() (
  _schedule_resume_lock_job_dir=$1
  _schedule_resume_lock_pid=$2
  _schedule_resume_lock_dir=$_schedule_resume_lock_job_dir/lock
  _schedule_resume_guard_file=$_schedule_resume_lock_job_dir/.lock-guard
  _schedule_resume_lockf=${RESUME_JOB_LOCKF:-/usr/bin/lockf}
  _schedule_resume_existing_pid=
  _schedule_resume_lock_pid_is_valid "$_schedule_resume_lock_pid" || return 1

  _schedule_resume_require_lockf "$_schedule_resume_lockf" || return 1
  exec 9>>"$_schedule_resume_guard_file" || return 1
  if "$_schedule_resume_lockf" -s 9; then
    :
  else
    _schedule_resume_lockf_result=$?
    printf 'schedule-resume lockf cleanup failed with exit %s for %s\n' \
      "$_schedule_resume_lockf_result" "$_schedule_resume_guard_file" >&2
    return "$_schedule_resume_lockf_result"
  fi

  [ -f "$_schedule_resume_lock_dir/pid" ] || return 0
  IFS= read -r _schedule_resume_existing_pid <"$_schedule_resume_lock_dir/pid" || return 1
  [ "$_schedule_resume_existing_pid" = "$_schedule_resume_lock_pid" ] || return 0

  rm -f "$_schedule_resume_lock_dir/pid" "$_schedule_resume_lock_dir/started_at" || return 1
  rmdir "$_schedule_resume_lock_dir" 2>/dev/null
)
