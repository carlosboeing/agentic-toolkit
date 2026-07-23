#!/bin/sh

# cron scheduler backend. One crontab line per job:
#
#   * * * * * '<wrapper>' # schedule-resume:<job-id>
#
# The line polls every minute; the next_attempt_at due-gate in run_job decides
# when an attempt actually runs. All crontab edits are serialized by a lock,
# scoped to lines carrying our marker, and preserve every foreign line verbatim.

_schedule_resume_crontab_lock_dir() {
  printf '%s/.crontab-lock\n' "${RESUME_JOB_STATE_ROOT%/}"
}

# Run "$@" while holding the shared crontab lock. Blocks (bounded) on contention
# so concurrent create/run/cancel/cleanup cannot clobber each other's edits.
_schedule_resume_with_crontab_lock() {
  _cronlk_dir=$(_schedule_resume_crontab_lock_dir) || return 1
  (umask 077; mkdir -p "$_cronlk_dir") || return 1
  _cronlk_pid=$$
  _cronlk_timeout=${RESUME_JOB_CRONTAB_LOCK_TIMEOUT_SECONDS:-10}
  case "$_cronlk_timeout" in '' | *[!0-9]*) _cronlk_timeout=10 ;; esac
  _cronlk_deadline=$(( $(date +%s) + _cronlk_timeout ))
  while :; do
    if schedule_resume_acquire_lock "$_cronlk_dir" "$_cronlk_pid"; then
      break
    fi
    _cronlk_result=$?
    if [ "$_cronlk_result" -ne 75 ]; then
      return "$_cronlk_result"
    fi
    if [ "$(date +%s)" -ge "$_cronlk_deadline" ]; then
      printf 'schedule-resume: crontab lock busy after %ss\n' "$_cronlk_timeout" >&2
      return 75
    fi
    /bin/sleep 0.05
  done
  if "$@"; then
    _cronlk_cmd_result=0
  else
    _cronlk_cmd_result=$?
  fi
  schedule_resume_release_lock "$_cronlk_dir" "$_cronlk_pid" >/dev/null 2>&1 || :
  return "$_cronlk_cmd_result"
}

# stdin filter: drop the single line ending with this job's marker; pass the rest
# through byte-for-byte. Literal suffix match, so job-1 never matches job-11 and
# wrapper paths with spaces or quotes are unaffected.
_schedule_resume_crontab_filter_out_job() {
  _cfo_marker="# schedule-resume:$1"
  while IFS= read -r _cfo_line || [ -n "$_cfo_line" ]; do
    case "$_cfo_line" in
      *"$_cfo_marker") : ;;
      *) printf '%s\n' "$_cfo_line" ;;
    esac
  done
}

# stdin filter: drop any schedule-resume line whose job directory no longer
# exists (or whose marker id is invalid); pass everything else through.
_schedule_resume_crontab_reconcile_filter() {
  while IFS= read -r _crf_line || [ -n "$_crf_line" ]; do
    case "$_crf_line" in
      *"# schedule-resume:"*)
        _crf_jid=${_crf_line##*# schedule-resume:}
        if schedule_resume_validate_job_id "$_crf_jid" >/dev/null 2>&1 &&
          [ -d "${RESUME_JOB_STATE_ROOT%/}/$_crf_jid" ]; then
          printf '%s\n' "$_crf_line"
        fi
        ;;
      *) printf '%s\n' "$_crf_line" ;;
    esac
  done
}

# Render the exact crontab line for a job. Single quotes in the wrapper path are
# escaped so paths containing spaces, quotes, or metacharacters stay intact.
schedule_resume_scheduler_line() (
  _ssl_job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  _ssl_wrapper=$2
  [ -n "$_ssl_wrapper" ] || return 1
  _ssl_escaped=$(printf '%s' "$_ssl_wrapper" | sed "s/'/'\\\\''/g") || return 1
  printf "* * * * * '%s' # schedule-resume:%s\n" "$_ssl_escaped" "$_ssl_job_id"
)

_schedule_resume_scheduler_install_locked() {
  _sil_job_id=$1
  _sil_wrapper=$2
  _sil_line=$(schedule_resume_scheduler_line "$_sil_job_id" "$_sil_wrapper") || return 1
  _sil_new=$(
    crontab -l 2>/dev/null | _schedule_resume_crontab_filter_out_job "$_sil_job_id"
    printf '%s\n' "$_sil_line"
  ) || return 1
  printf '%s\n' "$_sil_new" | crontab -
}

_schedule_resume_scheduler_remove_locked() {
  _srl_job_id=$1
  _srl_new=$(crontab -l 2>/dev/null | _schedule_resume_crontab_filter_out_job "$_srl_job_id")
  if [ -n "$_srl_new" ]; then
    printf '%s\n' "$_srl_new" | crontab -
  else
    crontab -r 2>/dev/null || :
  fi
}

_schedule_resume_scheduler_reconcile_locked() {
  _src_old=$(crontab -l 2>/dev/null) || _src_old=
  [ -n "$_src_old" ] || return 0
  _src_new=$(printf '%s\n' "$_src_old" | _schedule_resume_crontab_reconcile_filter)
  [ "$_src_new" = "$_src_old" ] && return 0
  if [ -n "$_src_new" ]; then
    printf '%s\n' "$_src_new" | crontab -
  else
    crontab -r 2>/dev/null || :
  fi
}

# Ensure this job's crontab line exists (idempotent).
schedule_resume_scheduler_install() {
  _ssi_job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  _ssi_wrapper=$2
  [ -n "$_ssi_wrapper" ] || return 1
  _schedule_resume_with_crontab_lock _schedule_resume_scheduler_install_locked "$_ssi_job_id" "$_ssi_wrapper"
}

# Remove this job's crontab line (idempotent).
schedule_resume_scheduler_remove() {
  _ssr_job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  _schedule_resume_with_crontab_lock _schedule_resume_scheduler_remove_locked "$_ssr_job_id"
}

# Drop any schedule-resume crontab line whose job directory is gone.
schedule_resume_scheduler_reconcile() {
  _schedule_resume_with_crontab_lock _schedule_resume_scheduler_reconcile_locked
}

# Return 0 only on macOS when the path is under a TCC-protected folder that a
# cron job cannot read without Full Disk Access.
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
