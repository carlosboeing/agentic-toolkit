#!/bin/sh

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

schedule_resume_install_launch_agent() (
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

schedule_resume_remove_launch_agent() (
  job_id=$(schedule_resume_validate_job_id "${1-}") || return 1
  plist=$(schedule_resume_launchd_plist_path "$job_id") || return 1
  _schedule_resume_bootout_service "$job_id" || return 1
  rm -f "$plist"
)
