#!/bin/sh

RESUME_JOB_CLI="$TESTS_DIR/../scripts/resume-job.sh"
scheduler_root="$TEST_TMPDIR/scheduler"
mkdir -p "$scheduler_root/project"
export RESUME_JOB_STATE_ROOT="$TEST_TMPDIR/state & scheduler's"
mkdir -p "$RESUME_JOB_STATE_ROOT"
prompt_source="$scheduler_root/prompt & source.txt"
printf '%s\n' 'Resume <carefully> & keep "$HOME".' 'No trailing interpretation: `uname`; * ?' >"$prompt_source"
cp "$prompt_source" "$scheduler_root/expected-prompt.txt"

export RESUME_TEST_LAUNCHCTL_LOG="$scheduler_root/launchctl.jsonl"
: >"$RESUME_TEST_LAUNCHCTL_LOG"

default_home="$TEST_TMPDIR/default-home"
default_job=default-state-root-job
mkdir -p "$default_home"
(
  unset RESUME_JOB_STATE_ROOT
  HOME="$default_home"
  export HOME
  "$RESUME_JOB_CLI" create \
    --target-harness codex \
    --session-id default-state-session \
    --project-dir "$scheduler_root/project" \
    --prompt-file "$prompt_source" \
    --schedule-type calendar \
    --first-attempt-at '2099-07-22T12:29:00Z' \
    --retry-interval-seconds 300 \
    --retry-policy until-completed \
    --completion-policy session-exits-zero \
    --permissions-mode full-auto \
    --job-id "$default_job"
) >"$scheduler_root/default-state-create-output"
assert_file_exists "$default_home/.local/state/resume-job/$default_job/manifest.json" "default state root follows the public contract"
pass "default state root"
: >"$RESUME_TEST_LAUNCHCTL_LOG"

create_job() {
  "$RESUME_JOB_CLI" create \
    --target-harness codex \
    --session-id 'session & id' \
    --project-dir "$scheduler_root/project" \
    --prompt-file "$prompt_source" \
    --schedule-type calendar \
    --first-attempt-at "$1" \
    --retry-interval-seconds 300 \
    --retry-policy until-completed \
    --completion-policy session-exits-zero \
    --permissions-mode full-auto \
    --job-id "$2"
}

job_id='calendar-special-job'
assert_equal "$job_id" "$(create_job '2099-07-22T12:30:00Z' "$job_id")" "print created job ID"
job_dir="$RESUME_JOB_STATE_ROOT/$job_id"
plist="$HOME/Library/LaunchAgents/com.carlos.resume-job.$job_id.plist"
wrapper="$job_dir/run.sh"
assert_file_exists "$job_dir/manifest.json" "create manifest"
assert_file_exists "$job_dir/status.json" "create status"
assert_file_exists "$job_dir/prompt.txt" "copy owned prompt"
assert_file_exists "$wrapper" "create per-job wrapper"
assert_file_exists "$plist" "create launch agent plist"
[ -x "$wrapper" ] || fail "per-job wrapper must be executable"
grep -Fxq 'umask 077' "$wrapper" || fail "wrapper must enforce a private umask"
cmp -s "$scheduler_root/expected-prompt.txt" "$job_dir/prompt.txt" || fail "owned prompt must preserve exact bytes"
assert_equal "$job_dir/prompt.txt" "$(jq -r '.prompt_file' "$job_dir/manifest.json")" "manifest points to owned prompt"
assert_equal "$TESTS_DIR/fixtures/bin/codex" "$(jq -r '.harness_executable' "$job_dir/manifest.json")" "manifest persists the resolved harness executable"
/usr/bin/plutil -lint "$plist" >/dev/null || fail "generated plist must be valid XML"
assert_equal "com.carlos.resume-job.$job_id" "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="Label"]/following-sibling::string[1])' "$plist")" "plist label must be unique"
assert_equal "$wrapper" "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="ProgramArguments"]/following-sibling::array[1]/string[1])' "$plist")" "plist ProgramArguments must point to wrapper"
assert_equal "$job_dir/launchd.stdout.log" "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="StandardOutPath"]/following-sibling::string[1])' "$plist")" "plist stdout path must point to job log"
assert_equal "$job_dir/launchd.stderr.log" "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="StandardErrorPath"]/following-sibling::string[1])' "$plist")" "plist stderr path must point to job log"
assert_equal 63 "$(/usr/bin/xmllint --xpath 'string(/plist/dict/key[.="Umask"]/following-sibling::integer[1])' "$plist")" "plist must create logs with a private umask"
[ "$(stat -f '%Lp' "$job_dir")" = 700 ] || fail "job directory must be private"
[ "$(stat -f '%Lp' "$job_dir/manifest.json")" = 600 ] || fail "manifest must be private"
[ "$(stat -f '%Lp' "$job_dir/status.json")" = 600 ] || fail "status must be private"
[ "$(stat -f '%Lp' "$job_dir/prompt.txt")" = 600 ] || fail "prompt must be private"
[ "$(stat -f '%Lp' "$wrapper")" = 700 ] || fail "wrapper must be private"
grep -Fq '<key>StartCalendarInterval</key>' "$plist" || fail "plist must contain first-attempt calendar trigger"
grep -Fq '<key>StartInterval</key>' "$plist" || fail "plist must contain retry interval trigger"
grep -Fq '<integer>120</integer>' "$plist" || fail "plist poll trigger must use the fixed poll interval"
if grep -Fq '<integer>300</integer>' "$plist"; then
  fail "plist poll trigger must not depend on the manifest retry interval"
fi
uid=$(id -u)
assert_equal "[\"bootstrap\",\"gui/$uid\",\"$plist\"]" "$(sed -n '1p' "$RESUME_TEST_LAUNCHCTL_LOG")" "bootstrap only in user GUI domain"
pass "create and launchd plist contract"

seconds_job=seconds-calendar-job
assert_command_fails "reject calendar first attempts with non-zero seconds" create_job '2099-07-22T12:30:30Z' "$seconds_job"
assert_path_not_exists "$RESUME_JOB_STATE_ROOT/$seconds_job" "non-zero first-attempt seconds must not create state"
pass "minute-granular first attempt contract"

relative_prompt='basename prompt.txt'
cp "$prompt_source" "$scheduler_root/$relative_prompt"
relative_job=relative-prompt-job
(
  cd "$scheduler_root" || exit 1
  "$RESUME_JOB_CLI" create \
    --target-harness codex \
    --session-id relative-session \
    --project-dir project \
    --prompt-file "$relative_prompt" \
    --schedule-type reset \
    --first-attempt-at '2099-07-22T12:30:00Z' \
    --retry-interval-seconds 300 \
    --retry-policy until-completed \
    --completion-policy session-exits-zero \
    --permissions-mode full-auto \
    --job-id "$relative_job"
) >"$scheduler_root/relative-create-output"
assert_equal "$relative_job" "$(cat "$scheduler_root/relative-create-output")" "accept relative basename prompt"
cmp -s "$scheduler_root/$relative_prompt" "$RESUME_JOB_STATE_ROOT/$relative_job/prompt.txt" || fail "relative basename prompt must preserve exact bytes"
pass "relative basename prompt path"

timezone_job=timezone-calendar-job
(
  export TZ=America/Los_Angeles
  create_job '2026-07-01T12:30:00Z' "$timezone_job"
) >/dev/null
timezone_plist="$HOME/Library/LaunchAgents/com.carlos.resume-job.$timezone_job.plist"
calendar_xpath='/plist/dict/key[.="StartCalendarInterval"]/following-sibling::dict[1]'
assert_equal 4 "$(/usr/bin/xmllint --xpath "count($calendar_xpath/key)" "$timezone_plist")" "calendar trigger has exactly four supported fields"
assert_equal 0 "$(/usr/bin/xmllint --xpath "count($calendar_xpath/key[.=\"Year\"])" "$timezone_plist")" "calendar trigger omits unsupported Year"
assert_equal 07 "$(/usr/bin/xmllint --xpath "string($calendar_xpath/key[.=\"Month\"]/following-sibling::integer[1])" "$timezone_plist")" "calendar month uses target timezone"
assert_equal 01 "$(/usr/bin/xmllint --xpath "string($calendar_xpath/key[.=\"Day\"]/following-sibling::integer[1])" "$timezone_plist")" "calendar day uses target timezone"
assert_equal 05 "$(/usr/bin/xmllint --xpath "string($calendar_xpath/key[.=\"Hour\"]/following-sibling::integer[1])" "$timezone_plist")" "DST calendar hour converts from UTC"
assert_equal 30 "$(/usr/bin/xmllint --xpath "string($calendar_xpath/key[.=\"Minute\"]/following-sibling::integer[1])" "$timezone_plist")" "calendar minute converts from UTC"
pass "supported launchd calendar fields and timezone conversion"

for invalid_policy_case in retry-policy completion-policy permissions-mode; do
  invalid_policy_job="invalid-$invalid_policy_case"
  invalid_policy_args='--retry-policy until-completed --completion-policy session-exits-zero --permissions-mode full-auto'
  case "$invalid_policy_case" in
    retry-policy) invalid_policy_args='--retry-policy forever --completion-policy session-exits-zero --permissions-mode full-auto' ;;
    completion-policy) invalid_policy_args='--retry-policy until-completed --completion-policy any-exit --permissions-mode full-auto' ;;
    permissions-mode) invalid_policy_args='--retry-policy until-completed --completion-policy session-exits-zero --permissions-mode unsafe' ;;
  esac
  set -- $invalid_policy_args
  assert_command_fails "reject unsupported $invalid_policy_case" \
    "$RESUME_JOB_CLI" create \
      --target-harness codex \
      --session-id invalid-policy-session \
      --project-dir "$scheduler_root/project" \
      --prompt-file "$prompt_source" \
      --schedule-type calendar \
      --first-attempt-at '2099-07-22T12:30:00Z' \
      --retry-interval-seconds 300 \
      "$@" \
      --job-id "$invalid_policy_job"
  assert_path_not_exists "$RESUME_JOB_STATE_ROOT/$invalid_policy_job" "unsupported $invalid_policy_case must not create state"
done
pass "policy value allowlists"

launchctl_calls_before_duplicate=$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')
assert_command_fails "reject duplicate job without replacing it" create_job '2099-07-22T12:30:00Z' "$job_id"
assert_equal "$launchctl_calls_before_duplicate" "$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')" "duplicate create must not call launchctl"

. "$LIB_DIR/common.sh"
. "$LIB_DIR/state.sh"
. "$LIB_DIR/lock.sh"
. "$LIB_DIR/adapters.sh"
. "$LIB_DIR/scheduler-launchd.sh"
reinstall_log_start=$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')
schedule_resume_install_launch_agent "$job_id" "$wrapper"
assert_equal "[\"bootout\",\"gui/$uid/com.carlos.resume-job.$job_id\"]" "$(sed -n "$((reinstall_log_start + 1))p" "$RESUME_TEST_LAUNCHCTL_LOG")" "reinstall boots out exact service"
assert_equal "[\"bootstrap\",\"gui/$uid\",\"$plist\"]" "$(sed -n "$((reinstall_log_start + 2))p" "$RESUME_TEST_LAUNCHCTL_LOG")" "reinstall bootstraps exact plist"
launchctl_calls_after_reinstall=$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')
export RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS=5
assert_command_fails "propagate arbitrary bootout errors" schedule_resume_install_launch_agent "$job_id" "$wrapper"
unset RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS
assert_equal "$((launchctl_calls_after_reinstall + 1))" "$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')" "failed bootout must prevent replacement bootstrap"
pass "idempotent launch agent replacement"

"$RESUME_JOB_CLI" list >"$scheduler_root/list-output"
grep -Fxq "$job_id" "$scheduler_root/list-output" || fail "list must include created job state"
"$RESUME_JOB_CLI" status "$job_id" >"$scheduler_root/status-output.json"
assert_json_equal "$(cat "$job_dir/status.json")" "$scheduler_root/status-output.json" "status reads mutable state"

export RESUME_TEST_HARNESS_LOG="$scheduler_root/due-gate.args"
export RESUME_TEST_PROMPT_CAPTURE="$scheduler_root/due-gate.prompt"
export RESUME_TEST_CWD_CAPTURE="$scheduler_root/due-gate.cwd"
export RESUME_TEST_EXIT_CODE=1
export RESUME_TEST_OUTPUT='Usage quota exceeded. Retry after reset.'
"$wrapper"
assert_path_not_exists "$RESUME_TEST_HARNESS_LOG" "early interval trigger must not launch target"

due_status=$(jq '.next_attempt_at = "2000-01-01T00:00:00Z"' "$job_dir/status.json")
schedule_resume_write_status "$job_id" "$due_status"
"$RESUME_JOB_CLI" run "$job_id"
assert_file_exists "$RESUME_TEST_HARNESS_LOG" "due trigger launches target"
assert_equal retrying "$(schedule_resume_read_status "$job_id")" "retryable result persists retrying"
rm -f "$RESUME_TEST_HARNESS_LOG"
"$RESUME_JOB_CLI" run "$job_id"
assert_path_not_exists "$RESUME_TEST_HARNESS_LOG" "retry interval before next due is harmless"
due_retry_status=$(jq '.next_attempt_at = "2000-01-01T00:00:00Z"' "$job_dir/status.json")
schedule_resume_write_status "$job_id" "$due_retry_status"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
"$RESUME_JOB_CLI" run "$job_id"
assert_equal completed "$(schedule_resume_read_status "$job_id")" "retry runs once due"
assert_equal 2 "$(jq -r '.attempt_count' "$job_dir/status.json")" "run exactly two due attempts"
pass "first-attempt and retry due-time gating"

cancel_job=cancel-preserves-state
create_job '2099-07-22T12:31:00Z' "$cancel_job" >/dev/null
cancel_dir="$RESUME_JOB_STATE_ROOT/$cancel_job"
export RESUME_TEST_LAUNCHCTL_STATUS_PATH="$cancel_dir/status.json"
"$RESUME_JOB_CLI" cancel "$cancel_job"
unset RESUME_TEST_LAUNCHCTL_STATUS_PATH
assert_equal scheduled "$(cat "$cancel_dir/status.json.at-bootout")" "cancel unloads service before publishing terminal state"
assert_equal cancelled "$(schedule_resume_read_status "$cancel_job")" "cancel marks job terminal"
assert_file_exists "$cancel_dir/manifest.json" "cancel preserves manifest"
assert_file_exists "$cancel_dir/prompt.txt" "cancel preserves prompt"
assert_equal "[\"bootout\",\"gui/$uid/com.carlos.resume-job.$cancel_job\"]" "$(tail -n 1 "$RESUME_TEST_LAUNCHCTL_LOG")" "cancel boots out exact service"
cancel_calls_before=$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')
export RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS=3
export RESUME_TEST_LAUNCHCTL_BOOTOUT_ERROR='Boot-out failed: 3: No such process'
"$RESUME_JOB_CLI" cancel "$cancel_job"
unset RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS RESUME_TEST_LAUNCHCTL_BOOTOUT_ERROR
cancel_calls_after=$(wc -l <"$RESUME_TEST_LAUNCHCTL_LOG" | tr -d ' ')
assert_equal "$((cancel_calls_before + 1))" "$cancel_calls_after" "repeated cancel still boots out exact service"
pass "cancel preserves state and logs"

cancel_race_job=cancel-running-attempt
create_job '2000-01-01T00:00:00Z' "$cancel_race_job" >/dev/null
cancel_race_dir="$RESUME_JOB_STATE_ROOT/$cancel_race_job"
cancel_race_harness_barrier="$scheduler_root/cancel-race-harness"
cancel_race_final_barrier="$scheduler_root/cancel-race-final"
mkdir -p "$cancel_race_harness_barrier" "$cancel_race_final_barrier"
export RESUME_TEST_HARNESS_LOG="$scheduler_root/cancel-race.args"
export RESUME_TEST_PROMPT_CAPTURE="$scheduler_root/cancel-race.prompt"
export RESUME_TEST_CWD_CAPTURE="$scheduler_root/cancel-race.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
export RESUME_TEST_HARNESS_BARRIER="$cancel_race_harness_barrier"
export RESUME_TEST_BEFORE_FINAL_STATUS_BARRIER="$cancel_race_final_barrier"
export RESUME_TEST_BEFORE_FINAL_STATUS_EXPECTED=completed
export RESUME_JOB_LOCKF="$TESTS_DIR/fixtures/bin/lockf-observe"
export RESUME_TEST_LOCK_ATTEMPT_FILE="$cancel_race_final_barrier/cancel-lock-attempt"
"$RESUME_JOB_CLI" run "$cancel_race_job" &
cancel_race_runner_pid=$!
cancel_race_wait_count=0
while ! find "$cancel_race_harness_barrier" -name 'launched.*' -type f | grep -q .; do
  cancel_race_wait_count=$((cancel_race_wait_count + 1))
  [ "$cancel_race_wait_count" -lt 500 ] || fail "blocking cancellation attempt did not launch"
  /bin/sleep 0.01
done
export RESUME_TEST_LAUNCHCTL_BOOTOUT_RELEASE="$cancel_race_harness_barrier/release"
export RESUME_TEST_LAUNCHCTL_BOOTOUT_WAIT_FOR="$cancel_race_final_barrier/ready"
(
  export RESUME_TEST_ACTOR=cancel
  if "$RESUME_JOB_CLI" cancel "$cancel_race_job" >"$scheduler_root/cancel-race.stdout" 2>"$scheduler_root/cancel-race.stderr"; then
    printf '0\n' >"$scheduler_root/cancel-race.result"
  else
    printf '%s\n' "$?" >"$scheduler_root/cancel-race.result"
  fi
) &
cancel_race_cancel_pid=$!
cancel_race_wait_count=0
while [ ! -e "$cancel_race_final_barrier/ready" ]; do
  cancel_race_wait_count=$((cancel_race_wait_count + 1))
  [ "$cancel_race_wait_count" -lt 500 ] || fail "runner did not reach final publication barrier"
  /bin/sleep 0.01
done
cancel_race_wait_count=0
while [ ! -e "$RESUME_TEST_LOCK_ATTEMPT_FILE" ]; do
  cancel_race_wait_count=$((cancel_race_wait_count + 1))
  [ "$cancel_race_wait_count" -lt 500 ] || fail "cancel did not attempt the shared job lock"
  /bin/sleep 0.01
done
assert_path_not_exists "$scheduler_root/cancel-race.result" "cancel must wait while attempt owns lock"
touch "$cancel_race_final_barrier/release"
wait "$cancel_race_runner_pid"
wait "$cancel_race_cancel_pid"
unset RESUME_TEST_HARNESS_BARRIER RESUME_TEST_BEFORE_FINAL_STATUS_BARRIER RESUME_TEST_BEFORE_FINAL_STATUS_EXPECTED
unset RESUME_TEST_LAUNCHCTL_BOOTOUT_RELEASE RESUME_TEST_LAUNCHCTL_BOOTOUT_WAIT_FOR
unset RESUME_JOB_LOCKF RESUME_TEST_LOCK_ATTEMPT_FILE
assert_equal 0 "$(cat "$scheduler_root/cancel-race.result")" "cancel succeeds after serialized attempt completion"
assert_equal cancelled "$(schedule_resume_read_status "$cancel_race_job")" "runner cannot overwrite serialized cancellation"
assert_equal success "$(jq -r '.last_classification' "$cancel_race_dir/status.json")" "cancellation preserves attempt fields"
pass "cancel serializes with running attempt"

cancel_pid_job=cancel-owner-pid
create_job '2099-07-22T12:32:00Z' "$cancel_pid_job" >/dev/null
cancel_pid_dir="$RESUME_JOB_STATE_ROOT/$cancel_pid_job"
cancel_pid_barrier="$scheduler_root/cancel-pid-barrier"
mkdir -p "$cancel_pid_barrier"
export RESUME_TEST_BEFORE_FINAL_STATUS_BARRIER="$cancel_pid_barrier"
export RESUME_TEST_BEFORE_FINAL_STATUS_EXPECTED=cancelled
(
  "$RESUME_JOB_CLI" cancel "$cancel_pid_job" >"$scheduler_root/cancel-pid.stdout" 2>"$scheduler_root/cancel-pid.stderr" &
  cancel_pid_cli=$!
  printf '%s\n' "$cancel_pid_cli" >"$cancel_pid_barrier/cli-pid"
  if wait "$cancel_pid_cli"; then
    printf '0\n' >"$cancel_pid_barrier/cli-result"
  else
    printf '%s\n' "$?" >"$cancel_pid_barrier/cli-result"
  fi
  touch "$cancel_pid_barrier/cli-finished"
  cancel_pid_parent_wait=0
  while [ ! -e "$cancel_pid_barrier/release-parent" ]; do
    cancel_pid_parent_wait=$((cancel_pid_parent_wait + 1))
    [ "$cancel_pid_parent_wait" -lt 500 ] || exit 1
    /bin/sleep 0.01
  done
) &
cancel_pid_parent=$!
cancel_pid_wait_count=0
while [ ! -e "$cancel_pid_barrier/ready" ] || [ ! -e "$cancel_pid_barrier/cli-pid" ]; do
  cancel_pid_wait_count=$((cancel_pid_wait_count + 1))
  [ "$cancel_pid_wait_count" -lt 500 ] || fail "cancellation did not reach PID ownership barrier"
  /bin/sleep 0.01
done
cancel_pid_recorded=$(cat "$cancel_pid_dir/lock/pid")
cancel_pid_cli=$(cat "$cancel_pid_barrier/cli-pid")
if [ "$cancel_pid_recorded" = "$cancel_pid_cli" ]; then
  touch "$cancel_pid_barrier/release"
  cancel_pid_wait_count=0
  while [ ! -e "$cancel_pid_barrier/cli-finished" ]; do
    cancel_pid_wait_count=$((cancel_pid_wait_count + 1))
    [ "$cancel_pid_wait_count" -lt 500 ] || break
    /bin/sleep 0.01
  done
  touch "$cancel_pid_barrier/release-parent"
  wait "$cancel_pid_parent" 2>/dev/null || :
  fail "cancellation lock owner must be the function subshell PID, not its live CLI parent"
fi
kill -KILL "$cancel_pid_recorded"
cancel_pid_wait_count=0
while [ ! -e "$cancel_pid_barrier/cli-finished" ]; do
  cancel_pid_wait_count=$((cancel_pid_wait_count + 1))
  [ "$cancel_pid_wait_count" -lt 500 ] || fail "cancel CLI did not observe owner crash"
  /bin/sleep 0.01
done
kill -0 "$cancel_pid_parent" 2>/dev/null || fail "test parent must remain alive during stale lock recovery"
schedule_resume_acquire_lock "$cancel_pid_dir" "$$"
schedule_resume_release_lock "$cancel_pid_dir" "$$"
touch "$cancel_pid_barrier/release-parent"
wait "$cancel_pid_parent"
unset RESUME_TEST_BEFORE_FINAL_STATUS_BARRIER RESUME_TEST_BEFORE_FINAL_STATUS_EXPECTED
assert_equal scheduled "$(schedule_resume_read_status "$cancel_pid_job")" "owner crash before publication preserves prior status"
pass "cancellation records actual lock owner PID"

cancel_timeout_job=cancel-live-owner-timeout
create_job '2099-07-22T12:33:00Z' "$cancel_timeout_job" >/dev/null
cancel_timeout_dir="$RESUME_JOB_STATE_ROOT/$cancel_timeout_job"
/bin/sleep 30 &
cancel_timeout_owner=$!
schedule_resume_acquire_lock "$cancel_timeout_dir" "$cancel_timeout_owner"
export RESUME_JOB_CANCEL_LOCK_TIMEOUT_SECONDS=0
if "$RESUME_JOB_CLI" cancel "$cancel_timeout_job" >"$scheduler_root/cancel-timeout.stdout" 2>"$scheduler_root/cancel-timeout.stderr"; then
  fail "cancel must fail while a direct live owner retains the lock"
else
  cancel_timeout_result=$?
fi
unset RESUME_JOB_CANCEL_LOCK_TIMEOUT_SECONDS
assert_equal 75 "$cancel_timeout_result" "cancel timeout reports temporary lock contention"
grep -Fq "cannot cancel job $cancel_timeout_job" "$scheduler_root/cancel-timeout.stderr" || fail "cancel timeout must be actionable"
assert_equal scheduled "$(schedule_resume_read_status "$cancel_timeout_job")" "failed cancellation must not claim cancelled"
kill "$cancel_timeout_owner"
wait "$cancel_timeout_owner" 2>/dev/null || :
schedule_resume_release_lock "$cancel_timeout_dir" "$cancel_timeout_owner"
pass "cancel reports bounded live-owner timeout"

retention_bounds_root="$TEST_TMPDIR/retention-bounds-state"
mkdir -p "$retention_bounds_root"
RESUME_JOB_STATE_ROOT="$retention_bounds_root" "$RESUME_JOB_CLI" cleanup 0
RESUME_JOB_STATE_ROOT="$retention_bounds_root" "$RESUME_JOB_CLI" cleanup 36500
RESUME_JOB_STATE_ROOT="$retention_bounds_root" "$RESUME_JOB_CLI" cleanup 00009
RESUME_JOB_STATE_ROOT="$retention_bounds_root" "$RESUME_JOB_CLI" cleanup 000000
saved_state_root=$RESUME_JOB_STATE_ROOT
export RESUME_JOB_STATE_ROOT=$retention_bounds_root
retention_sentinel=retention-overflow-sentinel
create_job '2099-07-22T12:34:00Z' "$retention_sentinel" >/dev/null
retention_sentinel_dir="$RESUME_JOB_STATE_ROOT/$retention_sentinel"
retention_sentinel_status=$(jq '.status = "completed" | .last_finished_at = "1900-01-01T00:00:00Z" | .next_attempt_at = null' "$retention_sentinel_dir/status.json")
schedule_resume_write_status "$retention_sentinel" "$retention_sentinel_status"
for invalid_retention in 36501 99999999999999999999999999999999999999999999999999; do
  if "$RESUME_JOB_CLI" cleanup "$invalid_retention" >"$scheduler_root/retention-$invalid_retention.stdout" 2>"$scheduler_root/retention-$invalid_retention.stderr"; then
    fail "reject cleanup retention $invalid_retention"
  fi
  grep -Fq 'RETENTION_DAYS must be a decimal integer from 0 through 36500' "$scheduler_root/retention-$invalid_retention.stderr" ||
    fail "cleanup retention $invalid_retention must explain valid bounds"
  assert_file_exists "$retention_sentinel_dir/status.json" "invalid retention $invalid_retention must never delete"
done
export RESUME_JOB_STATE_ROOT=$saved_state_root
pass "cleanup retention bounds and overflow safety"

cleanup_old=cleanup-old-terminal
create_job '2099-07-22T12:32:00Z' "$cleanup_old" >/dev/null
cleanup_old_dir="$RESUME_JOB_STATE_ROOT/$cleanup_old"
cleanup_old_status=$(jq '.status = "completed" | .last_finished_at = "2000-01-01T00:00:00Z" | .next_attempt_at = null' "$cleanup_old_dir/status.json")
schedule_resume_write_status "$cleanup_old" "$cleanup_old_status"
cleanup_active=cleanup-active
create_job '2099-07-22T12:33:00Z' "$cleanup_active" >/dev/null
cleanup_locked=cleanup-locked-terminal
create_job '2099-07-22T12:35:00Z' "$cleanup_locked" >/dev/null
cleanup_locked_dir="$RESUME_JOB_STATE_ROOT/$cleanup_locked"
cleanup_locked_status=$(jq '.status = "completed" | .last_finished_at = "2000-01-01T00:00:00Z" | .next_attempt_at = null' "$cleanup_locked_dir/status.json")
schedule_resume_write_status "$cleanup_locked" "$cleanup_locked_status"
/bin/sleep 30 &
cleanup_lock_owner=$!
schedule_resume_acquire_lock "$cleanup_locked_dir" "$cleanup_lock_owner"
cleanup_external="$TEST_TMPDIR/cleanup-external-target"
mkdir -p "$cleanup_external"
printf '%s\n' 'preserve external target' >"$cleanup_external/marker.txt"
ln -s "$cleanup_external" "$RESUME_JOB_STATE_ROOT/cleanup-symlink-job"
malformed_dir="$RESUME_JOB_STATE_ROOT/malformed-job"
mkdir -p "$malformed_dir"
printf '%s\n' '{bad json' >"$malformed_dir/status.json"

export RESUME_JOB_LOCKF="$TESTS_DIR/fixtures/bin/lockf-error"
if "$RESUME_JOB_CLI" cleanup 30 >"$scheduler_root/cleanup-lock-error.stdout" 2>"$scheduler_root/cleanup-lock-error.stderr"; then
  fail "cleanup must propagate operational lock errors"
else
  cleanup_lock_error_result=$?
fi
unset RESUME_JOB_LOCKF
assert_equal 69 "$cleanup_lock_error_result" "cleanup propagates lockf operational status"
grep -Fq 'lockf acquisition failed with exit 69' "$scheduler_root/cleanup-lock-error.stderr" || fail "cleanup lock failure must be diagnosed"
assert_file_exists "$cleanup_old_dir/status.json" "lock error preserves terminal state"

cleanup_bootout_failure=a-cleanup-bootout-failure
create_job '2099-07-22T12:36:00Z' "$cleanup_bootout_failure" >/dev/null
cleanup_bootout_failure_dir="$RESUME_JOB_STATE_ROOT/$cleanup_bootout_failure"
cleanup_bootout_failure_plist="$HOME/Library/LaunchAgents/com.carlos.resume-job.$cleanup_bootout_failure.plist"
cleanup_bootout_failure_status=$(jq '.status = "failed" | .last_finished_at = "2000-01-01T00:00:00Z" | .next_attempt_at = null' "$cleanup_bootout_failure_dir/status.json")
schedule_resume_write_status "$cleanup_bootout_failure" "$cleanup_bootout_failure_status"
export RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS=5
if "$RESUME_JOB_CLI" cleanup 30 >"$scheduler_root/cleanup-bootout-error.stdout" 2>"$scheduler_root/cleanup-bootout-error.stderr"; then
  fail "cleanup must propagate unexpected bootout failure"
fi
unset RESUME_TEST_LAUNCHCTL_BOOTOUT_STATUS
assert_file_exists "$cleanup_bootout_failure_dir/status.json" "bootout failure preserves job state"
assert_file_exists "$cleanup_bootout_failure_plist" "bootout failure preserves plist"

"$RESUME_JOB_CLI" cleanup 30 >"$scheduler_root/cleanup.stdout" 2>"$scheduler_root/cleanup.stderr"
assert_path_not_exists "$cleanup_old_dir" "cleanup removes old terminal job state"
assert_path_not_exists "$HOME/Library/LaunchAgents/com.carlos.resume-job.$cleanup_old.plist" "cleanup removes exact old plist"
assert_file_exists "$cleanup_locked_dir/status.json" "cleanup preserves live-locked terminal job"
grep -Fq "cleanup skipped job $cleanup_locked: lock is held" "$scheduler_root/cleanup.stderr" || fail "cleanup reports lock contention"
assert_file_exists "$RESUME_JOB_STATE_ROOT/$cleanup_active/status.json" "cleanup preserves active job"
assert_file_exists "$malformed_dir/status.json" "cleanup preserves malformed job"
assert_path_not_exists "$malformed_dir/.lock-guard" "cleanup skips malformed entries without creating lock artifacts"
assert_file_exists "$RESUME_JOB_STATE_ROOT/cleanup-symlink-job/marker.txt" "cleanup preserves symlink entry target"
assert_file_exists "$cleanup_external/marker.txt" "cleanup leaves external symlink target untouched"
assert_file_exists "$job_dir/status.json" "cleanup preserves recent terminal job"
kill "$cleanup_lock_owner"
wait "$cleanup_lock_owner" 2>/dev/null || :
schedule_resume_release_lock "$cleanup_locked_dir" "$cleanup_lock_owner"
pass "safe retention cleanup"

rollback_job=rollback-bootstrap-failure
export RESUME_TEST_LAUNCHCTL_BOOTSTRAP_STATUS=7
assert_command_fails "create reports bootstrap failure" create_job '2099-07-22T12:34:00Z' "$rollback_job"
unset RESUME_TEST_LAUNCHCTL_BOOTSTRAP_STATUS
assert_path_not_exists "$RESUME_JOB_STATE_ROOT/$rollback_job" "failed create removes only newly created state"
assert_path_not_exists "$HOME/Library/LaunchAgents/com.carlos.resume-job.$rollback_job.plist" "failed create removes new plist"
assert_file_exists "$RESUME_JOB_STATE_ROOT/$cleanup_active/status.json" "failed create preserves other jobs"
pass "create rollback scope"
