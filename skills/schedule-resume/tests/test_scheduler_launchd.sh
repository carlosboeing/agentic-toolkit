#!/bin/sh

# launchd backend tests (macOS). Covers the launchd-specific scheduler surface:
# plist contract, bootstrap/bootout ordering, no in-context self-removal,
# reconcile pruning, create preflight, and doctor output. Lock and state
# semantics are backend-independent and covered by the cron scheduler group.

RESUME_JOB_CLI="$TESTS_DIR/../scripts/resume-job.sh"
launchd_root="$TEST_TMPDIR/launchd"
mkdir -p "$launchd_root/project"
export RESUME_JOB_STATE_ROOT="$TEST_TMPDIR/state & launchd's"
mkdir -p "$RESUME_JOB_STATE_ROOT"
launchd_prompt="$launchd_root/prompt & source.txt"
printf '%s\n' 'Resume <carefully> & keep "$HOME".' 'No trailing interpretation: `uname`; * ?' >"$launchd_prompt"
cp "$launchd_prompt" "$launchd_root/expected-prompt.txt"

export RESUME_JOB_SCHEDULER=launchd
export RESUME_TEST_LAUNCHCTL_LOG="$launchd_root/launchctl.jsonl"
: >"$RESUME_TEST_LAUNCHCTL_LOG"

launchd_create_job() {
  "$RESUME_JOB_CLI" create \
    --target-harness codex \
    --session-id 'session & id' \
    --project-dir "$launchd_root/project" \
    --prompt-file "$launchd_prompt" \
    --schedule-type calendar \
    --first-attempt-at "$1" \
    --retry-interval-seconds 300 \
    --retry-policy until-completed \
    --completion-policy session-exits-zero \
    --permissions-mode full-auto \
    --job-id "$2"
}

launchd_plist_for() {
  printf '%s/Library/LaunchAgents/com.carlos.resume-job.%s.plist\n' "$HOME" "$1"
}

launchd_job='launchd-plist-job'
assert_equal "$launchd_job" "$(launchd_create_job '2099-07-22T12:30:00Z' "$launchd_job")" "print created job ID"
launchd_job_dir="$RESUME_JOB_STATE_ROOT/$launchd_job"
launchd_plist=$(launchd_plist_for "$launchd_job")
launchd_wrapper="$launchd_job_dir/run.sh"
assert_file_exists "$launchd_job_dir/manifest.json" "create manifest"
assert_file_exists "$launchd_job_dir/status.json" "create status"
assert_file_exists "$launchd_job_dir/prompt.txt" "copy owned prompt"
assert_file_exists "$launchd_wrapper" "create per-job wrapper"
assert_file_exists "$launchd_plist" "create launch agent plist"
cmp -s "$launchd_root/expected-prompt.txt" "$launchd_job_dir/prompt.txt" || fail "owned prompt must preserve exact bytes"
/usr/bin/plutil -lint "$launchd_plist" >/dev/null || fail "generated plist must be valid XML"
assert_equal "com.carlos.resume-job.$launchd_job" "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="Label"]/following-sibling::string[1])' "$launchd_plist")" "plist label must be unique"
assert_equal "$launchd_wrapper" "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="ProgramArguments"]/following-sibling::array[1]/string[1])' "$launchd_plist")" "plist ProgramArguments must point to wrapper"
assert_equal "$launchd_job_dir/launchd.stdout.log" "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="StandardOutPath"]/following-sibling::string[1])' "$launchd_plist")" "plist stdout path must point to job log"
assert_equal "$launchd_job_dir/launchd.stderr.log" "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="StandardErrorPath"]/following-sibling::string[1])' "$launchd_plist")" "plist stderr path must point to job log"
assert_equal 63 "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="Umask"]/following-sibling::integer[1])' "$launchd_plist")" "plist must create logs with a private umask"
grep -Fq '<key>StartCalendarInterval</key>' "$launchd_plist" || fail "plist must contain first-attempt calendar trigger"
grep -Fq '<key>StartInterval</key>' "$launchd_plist" || fail "plist must contain the poll trigger"
grep -Fq '<integer>60</integer>' "$launchd_plist" || fail "plist poll trigger must use the shared fixed poll interval"
if grep -Fq '<integer>300</integer>' "$launchd_plist"; then
  fail "plist poll trigger must not depend on the manifest retry interval"
fi
launchd_uid=$(id -u)
assert_equal "[\"print\",\"gui/$launchd_uid\"]" "$(sed -n '1p' "$RESUME_TEST_LAUNCHCTL_LOG")" "create preflights the user GUI domain"
assert_equal "[\"bootstrap\",\"gui/$launchd_uid\",\"$launchd_plist\"]" "$(tail -n 1 "$RESUME_TEST_LAUNCHCTL_LOG")" "bootstrap only in user GUI domain"
pass "create and launchd plist contract"

launchd_tz_job=launchd-timezone-job
(
  export TZ=America/Los_Angeles
  launchd_create_job '2026-07-01T12:30:00Z' "$launchd_tz_job"
) >/dev/null
launchd_tz_plist=$(launchd_plist_for "$launchd_tz_job")
launchd_calendar_xpath='/plist/dict/key[.="StartCalendarInterval"]/following-sibling::dict[1]'
assert_equal 4 "$(/usr/bin/xmllint --xpath "count($launchd_calendar_xpath/key)" "$launchd_tz_plist")" "calendar trigger has exactly four supported fields"
assert_equal 0 "$(/usr/bin/xmllint --xpath "count($launchd_calendar_xpath/key[.=\"Year\"])" "$launchd_tz_plist")" "calendar trigger omits unsupported Year"
assert_equal 07 "$(/usr/bin/xmllint --xpath "string($launchd_calendar_xpath/key[.=\"Month\"]/following-sibling::integer[1])" "$launchd_tz_plist")" "calendar month uses target timezone"
assert_equal 01 "$(/usr/bin/xmllint --xpath "string($launchd_calendar_xpath/key[.=\"Day\"]/following-sibling::integer[1])" "$launchd_tz_plist")" "calendar day uses target timezone"
assert_equal 05 "$(/usr/bin/xmllint --xpath "string($launchd_calendar_xpath/key[.=\"Hour\"]/following-sibling::integer[1])" "$launchd_tz_plist")" "DST calendar hour converts from UTC"
assert_equal 30 "$(/usr/bin/xmllint --xpath "string($launchd_calendar_xpath/key[.=\"Minute\"]/following-sibling::integer[1])" "$launchd_tz_plist")" "calendar minute converts from UTC"
pass "supported launchd calendar fields and timezone conversion"

# Direct scheduler calls need the libraries in this shell.
. "$LIB_DIR/common.sh"
. "$LIB_DIR/state.sh"
. "$LIB_DIR/lock.sh"
. "$LIB_DIR/adapters.sh"
. "$LIB_DIR/scheduler-launchd.sh"

launchd_reinstall_start=$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')
schedule_resume_scheduler_install "$launchd_job" "$launchd_wrapper"
assert_equal "[\"bootout\",\"gui/$launchd_uid/com.carlos.resume-job.$launchd_job\"]" "$(sed -n "$((launchd_reinstall_start + 1))p" "$RESUME_TEST_LAUNCHCTL_LOG")" "reinstall boots out exact service"
assert_equal "[\"bootstrap\",\"gui/$launchd_uid\",\"$launchd_plist\"]" "$(sed -n "$((launchd_reinstall_start + 2))p" "$RESUME_TEST_LAUNCHCTL_LOG")" "reinstall bootstraps exact plist"
launchd_after_reinstall=$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')
export RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS=5
assert_command_fails "propagate arbitrary bootout errors" schedule_resume_scheduler_install "$launchd_job" "$launchd_wrapper"
unset RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS
assert_equal "$((launchd_after_reinstall + 1))" "$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')" "failed bootout must prevent replacement bootstrap"
pass "idempotent launch agent replacement"

# Terminal transition must NOT self-remove from a launchd child: the plist
# stays, run logs the pruning note, and reconcile prunes it interactively.
launchd_done_job=launchd-terminal-keeps-plist
launchd_create_job '2000-01-01T00:00:00Z' "$launchd_done_job" >/dev/null
launchd_done_plist=$(launchd_plist_for "$launchd_done_job")
launchd_bootouts_before_run=$(grep -c '"bootout"' "$RESUME_TEST_LAUNCHCTL_LOG" || :)
export RESUME_TEST_HARNESS_LOG="$launchd_root/terminal.args"
export RESUME_TEST_PROMPT_CAPTURE="$launchd_root/terminal.prompt"
export RESUME_TEST_CWD_CAPTURE="$launchd_root/terminal.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
"$RESUME_JOB_CLI" run "$launchd_done_job" 2>"$launchd_root/terminal.stderr"
assert_equal completed "$(schedule_resume_read_status "$launchd_done_job")" "terminal attempt completes"
assert_file_exists "$launchd_done_plist" "terminal transition keeps the plist under launchd"
assert_equal "$launchd_bootouts_before_run" "$(grep -c '"bootout"' "$RESUME_TEST_LAUNCHCTL_LOG" || :)" "run must not bootout from a launchd child"
grep -Fq "pruned by the next interactive schedule-resume command" "$launchd_root/terminal.stderr" || fail "terminal transition must log the pruning note"
"$RESUME_JOB_CLI" run "$launchd_done_job" 2>"$launchd_root/terminal-again.stderr"
assert_file_exists "$launchd_done_plist" "polling a terminal job keeps the plist"
if [ -s "$launchd_root/terminal-again.stderr" ]; then
  fail "polling a terminal job must stay silent"
fi
pass "terminal transition defers entry removal under launchd"

schedule_resume_scheduler_reconcile
assert_path_not_exists "$launchd_done_plist" "reconcile prunes a terminal job's plist"
grep -Fq "\"bootout\",\"gui/$launchd_uid/com.carlos.resume-job.$launchd_done_job\"" "$RESUME_TEST_LAUNCHCTL_LOG" || fail "reconcile must bootout the pruned service"
assert_file_exists "$RESUME_JOB_STATE_ROOT/$launchd_done_job/status.json" "reconcile preserves terminal job state"
pass "reconcile prunes terminal launchd entries"

launchd_orphan_job=launchd-reconcile-orphan
launchd_create_job '2099-07-22T12:40:00Z' "$launchd_orphan_job" >/dev/null
launchd_orphan_plist=$(launchd_plist_for "$launchd_orphan_job")
assert_file_exists "$launchd_orphan_plist" "reconcile fixture starts with a plist"
rm -rf "$RESUME_JOB_STATE_ROOT/$launchd_orphan_job"
schedule_resume_scheduler_reconcile
assert_path_not_exists "$launchd_orphan_plist" "reconcile drops a plist whose job directory is gone"
assert_file_exists "$launchd_plist" "reconcile keeps a scheduled job's plist"
pass "reconcile prunes orphan launchd entries"

launchd_cancel_job=launchd-cancel-job
launchd_create_job '2099-07-22T12:31:00Z' "$launchd_cancel_job" >/dev/null
launchd_cancel_dir="$RESUME_JOB_STATE_ROOT/$launchd_cancel_job"
export RESUME_TEST_LAUNCHCTL_STATUS_PATH="$launchd_cancel_dir/status.json"
"$RESUME_JOB_CLI" cancel "$launchd_cancel_job"
unset RESUME_TEST_LAUNCHCTL_STATUS_PATH
assert_equal scheduled "$(cat "$launchd_cancel_dir/status.json.at-bootout")" "cancel unloads service before publishing terminal state"
assert_equal cancelled "$(schedule_resume_read_status "$launchd_cancel_job")" "cancel marks job terminal"
assert_path_not_exists "$(launchd_plist_for "$launchd_cancel_job")" "cancel removes the plist"
assert_file_exists "$launchd_cancel_dir/manifest.json" "cancel preserves manifest"
"$RESUME_JOB_CLI" cancel "$launchd_cancel_job"
assert_equal cancelled "$(schedule_resume_read_status "$launchd_cancel_job")" "repeated cancel stays terminal"
pass "cancel removes the launch agent"

launchd_cleanup_job=launchd-cleanup-old
launchd_create_job '2099-07-22T12:32:00Z' "$launchd_cleanup_job" >/dev/null
launchd_cleanup_status=$(jq '.status = "completed" | .last_finished_at = "2000-01-01T00:00:00Z" | .next_attempt_at = null' "$RESUME_JOB_STATE_ROOT/$launchd_cleanup_job/status.json")
schedule_resume_write_status "$launchd_cleanup_job" "$launchd_cleanup_status"
export RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS=5
if "$RESUME_JOB_CLI" cleanup 30 >"$launchd_root/cleanup-bootout-error.stdout" 2>"$launchd_root/cleanup-bootout-error.stderr"; then
  fail "cleanup must propagate unexpected bootout failure"
fi
unset RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS
assert_file_exists "$RESUME_JOB_STATE_ROOT/$launchd_cleanup_job/status.json" "bootout failure preserves job state"
"$RESUME_JOB_CLI" cleanup 30 >"$launchd_root/cleanup.stdout" 2>"$launchd_root/cleanup.stderr"
assert_path_not_exists "$RESUME_JOB_STATE_ROOT/$launchd_cleanup_job" "cleanup removes old terminal job state"
assert_path_not_exists "$(launchd_plist_for "$launchd_cleanup_job")" "cleanup removes exact old plist"
assert_file_exists "$launchd_plist" "cleanup preserves scheduled job plist"
pass "cleanup removes launch agents with state"

launchd_rollback_job=launchd-rollback-bootstrap
export RESUME_TEST_LAUNCHCTL_BOOTSTRAP_STATUS=7
assert_command_fails "create reports bootstrap failure" launchd_create_job '2099-07-22T12:34:00Z' "$launchd_rollback_job"
unset RESUME_TEST_LAUNCHCTL_BOOTSTRAP_STATUS
assert_path_not_exists "$RESUME_JOB_STATE_ROOT/$launchd_rollback_job" "failed create removes only newly created state"
assert_path_not_exists "$(launchd_plist_for "$launchd_rollback_job")" "failed create removes new plist"
pass "create rollback scope"

launchd_preflight_job=launchd-no-gui-domain
export RESUME_TEST_LAUNCHCTL_PRINT_STATUS=1
assert_command_fails "create fails without a reachable GUI domain" launchd_create_job '2099-07-22T12:35:00Z' "$launchd_preflight_job"
unset RESUME_TEST_LAUNCHCTL_PRINT_STATUS
assert_path_not_exists "$RESUME_JOB_STATE_ROOT/$launchd_preflight_job" "failed preflight must not create state"
assert_path_not_exists "$(launchd_plist_for "$launchd_preflight_job")" "failed preflight must not install a plist"
pass "create preflight requires the GUI domain"

launchd_keychain_job=launchd-keychain-warning
export RESUME_TEST_SECURITY_STATUS=44
"$RESUME_JOB_CLI" create \
  --target-harness claude \
  --session-id launchd-keychain-session \
  --project-dir "$launchd_root/project" \
  --prompt-file "$launchd_prompt" \
  --schedule-type calendar \
  --first-attempt-at '2099-07-22T12:36:00Z' \
  --retry-interval-seconds 300 \
  --retry-policy until-completed \
  --completion-policy sentinel-output \
  --permissions-mode full-auto \
  --job-id "$launchd_keychain_job" \
  >"$launchd_root/keychain.stdout" 2>"$launchd_root/keychain.stderr"
unset RESUME_TEST_SECURITY_STATUS
assert_file_exists "$RESUME_JOB_STATE_ROOT/$launchd_keychain_job/manifest.json" "missing keychain item warns without blocking create"
grep -Fiq 'keychain' "$launchd_root/keychain.stderr" || fail "create must warn when the Claude keychain item is unreadable"
pass "create preflight warns on a missing Claude keychain item"

launchd_zombie_job=launchd-doctor-zombie
launchd_create_job '2099-07-22T12:37:00Z' "$launchd_zombie_job" >/dev/null
launchd_zombie_status=$(jq '.status = "failed" | .last_finished_at = "2099-01-01T00:00:00Z" | .next_attempt_at = null' "$RESUME_JOB_STATE_ROOT/$launchd_zombie_job/status.json")
schedule_resume_write_status "$launchd_zombie_job" "$launchd_zombie_status"
launchd_ghost_plist="$HOME/Library/LaunchAgents/com.carlos.resume-job.launchd-ghost-no-dir.plist"
cp "$launchd_plist" "$launchd_ghost_plist"
"$RESUME_JOB_CLI" doctor >"$launchd_root/doctor.stdout" 2>"$launchd_root/doctor.stderr"
grep -Fq "$launchd_job  [live:" "$launchd_root/doctor.stdout" || fail "doctor must list live launchd jobs with status"
grep -Fq 'launchd-ghost-no-dir  [ORPHAN' "$launchd_root/doctor.stdout" || fail "doctor must flag orphan plists"
assert_path_not_exists "$launchd_ghost_plist" "doctor prunes orphan plists"
assert_path_not_exists "$(launchd_plist_for "$launchd_zombie_job")" "doctor prunes terminal-job plists"
assert_file_exists "$launchd_plist" "doctor keeps scheduled job plists"
pass "doctor lists and prunes launchd entries"

unset RESUME_TEST_HARNESS_LOG RESUME_TEST_PROMPT_CAPTURE RESUME_TEST_CWD_CAPTURE
export RESUME_JOB_SCHEDULER=cron
