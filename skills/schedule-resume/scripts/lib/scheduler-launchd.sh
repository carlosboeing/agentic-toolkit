#!/bin/sh

# launchd scheduler backend (macOS). One LaunchAgent per job in the user's GUI
# domain, where the login keychain is available to resumed harnesses:
#
#   ~/Library/LaunchAgents/com.carlos.resume-job.<job-id>.plist
#
# StartCalendarInterval pins the first attempt; StartInterval polls at the
# shared cadence and the next_attempt_at due-gate in run_job decides when an
# attempt actually runs. launchd never starts a second instance of a label, so
# long attempts are not re-entered.
#
# A launchd child must not bootout its own label (that kills its own process
# group mid-call), so terminal transitions leave the agent loaded and inert;
# interactive commands prune it via reconcile.
# shellcheck disable=SC2034  # consumed by run_job in resume-job.sh
SCHEDULE_RESUME_SCHEDULER_SELF_REMOVE=0

schedule_resume_launchd_label() (
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  printf 'com.carlos.resume-job.%s\n' "$job_id"
)

schedule_resume_launchd_plist_path() (
  label=$(schedule_resume_launchd_label "${1-}") || return 1
  printf '%s/Library/LaunchAgents/%s.plist\n' "${HOME:?HOME must be set}" "$label"
)

_schedule_resume_xml_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

_schedule_resume_bootout_service() (
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  label=$(schedule_resume_launchd_label "$job_id") || return 1
  domain="gui/$(id -u)"
  error_file=$(mktemp "${TMPDIR:-/tmp}/schedule-resume-bootout.XXXXXX") || return 1

  if launchctl bootout "$domain/$label" 2>"$error_file"; then
    rm -f "$error_file"
    return 0
  else
    result=$?
  fi
  if [ "$result" -eq 3 ] && grep -Eiq 'could not find specified service|no such process|not loaded' "$error_file"; then
    rm -f "$error_file"
    return 0
  fi
  cat "$error_file" >&2
  rm -f "$error_file"
  return "$result"
)

_schedule_resume_write_plist() (
  job_id=$1
  wrapper=$2
  destination=$3
  manifest=$(schedule_resume_read_manifest "$job_id") || return 1
  first_attempt_at=$(printf '%s\n' "$manifest" | jq -r '.first_attempt_at') || return 1
  first_epoch=$(_schedule_resume_timestamp_epoch "$first_attempt_at") || return 1
  label=$(schedule_resume_launchd_label "$job_id") || return 1
  job_dir=$(schedule_resume_job_dir "$job_id") || return 1

  calendar_minute=$(date -r "$first_epoch" '+%M') || return 1
  calendar_hour=$(date -r "$first_epoch" '+%H') || return 1
  calendar_day=$(date -r "$first_epoch" '+%d') || return 1
  calendar_month=$(date -r "$first_epoch" '+%m') || return 1
  escaped_label=$(printf '%s' "$label" | _schedule_resume_xml_escape) || return 1
  escaped_wrapper=$(printf '%s' "$wrapper" | _schedule_resume_xml_escape) || return 1
  escaped_stdout=$(printf '%s/launchd.stdout.log' "$job_dir" | _schedule_resume_xml_escape) || return 1
  escaped_stderr=$(printf '%s/launchd.stderr.log' "$job_dir" | _schedule_resume_xml_escape) || return 1

  cat >"$destination" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$escaped_label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$escaped_wrapper</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Minute</key><integer>$calendar_minute</integer>
    <key>Hour</key><integer>$calendar_hour</integer>
    <key>Day</key><integer>$calendar_day</integer>
    <key>Month</key><integer>$calendar_month</integer>
  </dict>
  <key>StartInterval</key>
  <integer>$SCHEDULE_RESUME_POLL_INTERVAL_SECONDS</integer>
  <key>Umask</key>
  <integer>63</integer>
  <key>StandardOutPath</key>
  <string>$escaped_stdout</string>
  <key>StandardErrorPath</key>
  <string>$escaped_stderr</string>
</dict>
</plist>
EOF
)

# Ensure this job's launch agent exists and is loaded (idempotent).
schedule_resume_scheduler_install() (
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  wrapper=${2-}
  [ -x "$wrapper" ] || return 1
  plist=$(schedule_resume_launchd_plist_path "$job_id") || return 1
  agents_dir=${plist%/*}
  mkdir -p "$agents_dir" || return 1
  temporary=$(mktemp "$agents_dir/.schedule-resume.XXXXXX") || return 1
  trap 'rm -f "$temporary"' 0 HUP INT TERM

  _schedule_resume_write_plist "$job_id" "$wrapper" "$temporary" || return 1
  plutil -lint "$temporary" >/dev/null || return 1
  if [ -e "$plist" ]; then
    _schedule_resume_bootout_service "$job_id" || return 1
  fi
  mv "$temporary" "$plist" || return 1
  temporary=
  launchctl bootstrap "gui/$(id -u)" "$plist"
)

# Remove this job's launch agent (idempotent).
schedule_resume_scheduler_remove() (
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  plist=$(schedule_resume_launchd_plist_path "$job_id") || return 1
  _schedule_resume_bootout_service "$job_id" || return 1
  rm -f "$plist"
)

# Prune launch agents whose job directory is gone or whose job reached a
# terminal state. Scheduled, retrying, and running jobs are never touched.
schedule_resume_scheduler_reconcile() (
  agents_dir="${HOME:?HOME must be set}/Library/LaunchAgents"
  result=0
  for plist in "$agents_dir"/com.carlos.resume-job.*.plist; do
    [ -e "$plist" ] || continue
    job_id=${plist##*/com.carlos.resume-job.}
    job_id=${job_id%.plist}
    schedule_resume_validate_job_id "$job_id" >/dev/null 2>&1 || continue
    if [ -d "$(schedule_resume_job_dir "$job_id" 2>/dev/null)" ] &&
      ! schedule_resume_job_is_terminal "$job_id"; then
      continue
    fi
    schedule_resume_scheduler_remove "$job_id" || result=$?
  done
  return "$result"
)

# Create-time preflight: the GUI domain must be reachable (a LaunchAgent cannot
# run without a logged-in GUI session), Claude targets need a readable keychain
# credential, and TCC-protected paths get a launchd-specific warning.
schedule_resume_scheduler_preflight() {
  _spf_target_harness=$1
  _spf_project_dir=$2
  _spf_prompt_file=$3
  _spf_state_root=$4
  if ! launchctl print "gui/$(id -u)" >/dev/null 2>&1; then
    printf 'error: launchd GUI domain gui/%s is not reachable (no logged-in GUI session?). Scheduled resumes need a GUI login; for headless Macs see the setup-token alternative in the schedule-resume docs.\n' "$(id -u)" >&2
    return 1
  fi
  if [ "$_spf_target_harness" = claude ] &&
    ! security find-generic-password -s "Claude Code-credentials" >/dev/null 2>&1; then
    printf 'warning: no "Claude Code-credentials" item is readable in the login keychain; the resumed claude session would start logged out and fail with authentication_terminal. Run claude and /login first.\n' >&2
  fi
  for _spf_path in "$_spf_project_dir" "$_spf_prompt_file" "$_spf_state_root"; do
    if schedule_resume_tcc_protected_path "$_spf_path"; then
      printf 'warning: %s is under a macOS TCC-protected folder; the background agent may be denied access. Grant access if the job cannot read its project or prompt.\n' "$_spf_path" >&2
    fi
  done
}

# Doctor: list schedule-resume launch agents with their job status, reconcile
# stale ones, flag loaded labels without a plist, and flag leftovers from the
# cron backend.
schedule_resume_scheduler_doctor() {
  _sdr_agents_dir="${HOME:?HOME must be set}/Library/LaunchAgents"
  printf 'schedule-resume launchd agents:\n'
  for _sdr_plist in "$_sdr_agents_dir"/com.carlos.resume-job.*.plist; do
    [ -e "$_sdr_plist" ] || continue
    _sdr_jid=${_sdr_plist##*/com.carlos.resume-job.}
    _sdr_jid=${_sdr_jid%.plist}
    if schedule_resume_validate_job_id "$_sdr_jid" >/dev/null 2>&1 &&
      [ -d "$(schedule_resume_job_dir "$_sdr_jid" 2>/dev/null)" ]; then
      _sdr_state=$(schedule_resume_read_status "$_sdr_jid" 2>/dev/null) || _sdr_state=unknown
      printf '  %s  [live: %s]\n' "$_sdr_jid" "$_sdr_state"
    else
      printf '  %s  [ORPHAN: no job directory]\n' "$_sdr_jid"
    fi
  done
  schedule_resume_scheduler_reconcile >/dev/null 2>&1 || :
  for _sdr_label in $(launchctl list 2>/dev/null | grep -o 'com\.carlos\.resume-job\.[A-Za-z0-9._-]*' || :); do
    if [ ! -e "$_sdr_agents_dir/$_sdr_label.plist" ]; then
      printf '  %s  [STALE-LOADED: no plist; bootout with: launchctl bootout gui/%s/%s]\n' "$_sdr_label" "$(id -u)" "$_sdr_label"
    fi
  done
  if crontab -l 2>/dev/null | grep -q '# schedule-resume:'; then
    printf '\nLeftover schedule-resume cron entries from the cron backend were found. Remove them with:\n'
    printf "  crontab -l | grep -v '# schedule-resume:' | crontab -\n"
  fi
  printf '\nTo purge every schedule-resume launch agent:\n'
  # shellcheck disable=SC2016  # deliberately printed verbatim for the user to run
  printf '  for p in "$HOME"/Library/LaunchAgents/com.carlos.resume-job.*.plist; do [ -e "$p" ] || continue; launchctl bootout "gui/$(id -u)/$(basename "$p" .plist)" 2>/dev/null; rm -f "$p"; done\n'
}
