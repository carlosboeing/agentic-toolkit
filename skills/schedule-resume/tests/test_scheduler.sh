#!/bin/sh

RESUME_JOB_CLI="$TESTS_DIR/../scripts/resume-job.sh"
scheduler_root="$TEST_TMPDIR/scheduler"
mkdir -p "$scheduler_root/project"
export RESUME_JOB_STATE_ROOT="$TEST_TMPDIR/state & scheduler's"
mkdir -p "$RESUME_JOB_STATE_ROOT"
prompt_source="$scheduler_root/prompt & source.txt"
printf '%s\n' 'Resume <carefully> & keep "$HOME".' 'No trailing interpretation: `uname`; * ?' >"$prompt_source"
cp "$prompt_source" "$scheduler_root/expected-prompt.txt"

# The crontab mock is backed by a single file; start each scheduler run clean.
export RESUME_TEST_CRONTAB_FILE="$scheduler_root/crontab"
rm -f "$RESUME_TEST_CRONTAB_FILE"

# Print only the schedule-resume crontab lines belonging to exactly this job id
# (literal suffix match, so job-1 never matches job-11).
cron_job_lines() {
  [ -f "$RESUME_TEST_CRONTAB_FILE" ] || return 0
  while IFS= read -r _cjl_line || [ -n "$_cjl_line" ]; do
    case "$_cjl_line" in
      *"# schedule-resume:$1") printf '%s\n' "$_cjl_line" ;;
    esac
  done <"$RESUME_TEST_CRONTAB_FILE"
}
cron_has_job() {
  [ -n "$(cron_job_lines "$1")" ]
}
assert_cron_has_job() {
  cron_has_job "$1" || fail "$2 (expected a crontab line for '$1')"
}
assert_cron_lacks_job() {
  [ -z "$(cron_job_lines "$1")" ] || fail "$2 (unexpected crontab line for '$1')"
}
count_cron_job_lines() {
  cron_job_lines "$1" | grep -c . || :
}

# A foreign crontab line that must survive every schedule-resume operation.
foreign_line='0 9 * * * /usr/bin/true # a foreign job'
printf '%s\n' "$foreign_line" | crontab -
assert_foreign_survives() {
  grep -Fxq "$foreign_line" "$RESUME_TEST_CRONTAB_FILE" || fail "$1 (foreign crontab line was clobbered)"
}

# Append a raw line to the crontab, reading the existing content into a variable
# first (a `crontab -l | crontab -` pipe would truncate the shared mock file).
crontab_append_raw() {
  _existing=$(crontab -l 2>/dev/null || :)
  { [ -z "$_existing" ] || printf '%s\n' "$_existing"; printf '%s\n' "$1"; } | crontab -
}

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
# The default-root job lives under a different state root; reset the shared
# crontab so its line does not confuse later reconcile sweeps.
rm -f "$RESUME_TEST_CRONTAB_FILE"
printf '%s\n' "$foreign_line" | crontab -

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
wrapper="$job_dir/run.sh"
assert_file_exists "$job_dir/manifest.json" "create manifest"
assert_file_exists "$job_dir/status.json" "create status"
assert_file_exists "$job_dir/prompt.txt" "copy owned prompt"
assert_file_exists "$wrapper" "create per-job wrapper"
[ -x "$wrapper" ] || fail "per-job wrapper must be executable"
grep -Fxq 'umask 077' "$wrapper" || fail "wrapper must enforce a private umask"
grep -Eq "^PATH='" "$wrapper" || fail "wrapper must pin a PATH for cron's minimal environment"
grep -Fq "/cron.log' 2>&1" "$wrapper" || fail "wrapper must redirect output to the job cron log"
cmp -s "$scheduler_root/expected-prompt.txt" "$job_dir/prompt.txt" || fail "owned prompt must preserve exact bytes"
assert_equal "$job_dir/prompt.txt" "$(jq -r '.prompt_file' "$job_dir/manifest.json")" "manifest points to owned prompt"
assert_equal "$TESTS_DIR/fixtures/bin/codex" "$(jq -r '.harness_executable' "$job_dir/manifest.json")" "manifest persists the resolved harness executable"
assert_cron_has_job "$job_id" "create installs a crontab line"
assert_equal 1 "$(count_cron_job_lines "$job_id")" "create installs exactly one crontab line"
cron_line=$(cron_job_lines "$job_id")
case "$cron_line" in
  '* * * * * '*) ;;
  *) fail "crontab line must poll every minute, not encode a specific time (got: $cron_line)" ;;
esac
case "$cron_line" in
  *"/run.sh' # schedule-resume:$job_id") ;;
  *) fail "crontab line must invoke the per-job wrapper with the marker" ;;
esac
assert_foreign_survives "create"
[ "$(stat -f '%Lp' "$job_dir")" = 700 ] || fail "job directory must be private"
[ "$(stat -f '%Lp' "$job_dir/manifest.json")" = 600 ] || fail "manifest must be private"
[ "$(stat -f '%Lp' "$job_dir/status.json")" = 600 ] || fail "status must be private"
[ "$(stat -f '%Lp' "$job_dir/prompt.txt")" = 600 ] || fail "prompt must be private"
[ "$(stat -f '%Lp' "$wrapper")" = 700 ] || fail "wrapper must be private"
pass "create and crontab line contract"

seconds_job=seconds-calendar-job
assert_command_fails "reject calendar first attempts with non-zero seconds" create_job '2099-07-22T12:30:30Z' "$seconds_job"
assert_path_not_exists "$RESUME_JOB_STATE_ROOT/$seconds_job" "non-zero first-attempt seconds must not create state"
assert_cron_lacks_job "$seconds_job" "rejected create must not install a crontab line"
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
assert_cron_has_job "$relative_job" "relative-prompt create installs a crontab line"
pass "relative basename prompt path"

for invalid_policy_case in retry-policy completion-policy permissions-mode; do
  invalid_policy_job="invalid-$invalid_policy_case"
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
  assert_cron_lacks_job "$invalid_policy_job" "unsupported $invalid_policy_case must not install a crontab line"
done
pass "policy value allowlists"

assert_command_fails "reject duplicate job without replacing it" create_job '2099-07-22T12:30:00Z' "$job_id"
assert_equal 1 "$(count_cron_job_lines "$job_id")" "duplicate create must not add a second crontab line"

# Source the libraries for direct scheduler / lock / attempt calls.
. "$LIB_DIR/common.sh"
. "$LIB_DIR/state.sh"
. "$LIB_DIR/lock.sh"
. "$LIB_DIR/adapters.sh"
. "$LIB_DIR/scheduler-cron.sh"

schedule_resume_scheduler_install "$job_id" "$wrapper"
schedule_resume_scheduler_install "$job_id" "$wrapper"
assert_equal 1 "$(count_cron_job_lines "$job_id")" "repeated install keeps exactly one crontab line"
assert_foreign_survives "idempotent install"
pass "idempotent crontab install"

reconcile_orphan_job=reconcile-orphan-job
create_job '2099-07-22T12:40:00Z' "$reconcile_orphan_job" >/dev/null
assert_cron_has_job "$reconcile_orphan_job" "reconcile fixture starts with a line"
rm -rf "$RESUME_JOB_STATE_ROOT/$reconcile_orphan_job"
schedule_resume_scheduler_reconcile
assert_cron_lacks_job "$reconcile_orphan_job" "reconcile drops a line whose job directory is gone"
assert_foreign_survives "reconcile"
pass "reconcile prunes orphan crontab lines"

export RESUME_TEST_HARNESS_LOG="$scheduler_root/due-gate.args"
export RESUME_TEST_PROMPT_CAPTURE="$scheduler_root/due-gate.prompt"
export RESUME_TEST_CWD_CAPTURE="$scheduler_root/due-gate.cwd"
export RESUME_TEST_EXIT_CODE=1
export RESUME_TEST_OUTPUT='Usage quota exceeded. Retry after reset.'
"$wrapper"
assert_path_not_exists "$RESUME_TEST_HARNESS_LOG" "early interval trigger must not launch target"
assert_cron_has_job "$job_id" "early trigger keeps the crontab line"

due_status=$(jq '.next_attempt_at = "2000-01-01T00:00:00Z"' "$job_dir/status.json")
schedule_resume_write_status "$job_id" "$due_status"
"$RESUME_JOB_CLI" run "$job_id"
assert_file_exists "$RESUME_TEST_HARNESS_LOG" "due trigger launches target"
assert_equal retrying "$(schedule_resume_read_status "$job_id")" "retryable result persists retrying"
assert_cron_has_job "$job_id" "a retrying job keeps its crontab line"
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
assert_cron_lacks_job "$job_id" "a completed job removes its own crontab line"
assert_foreign_survives "auto-removal on completion"
pass "first-attempt and retry due-time gating with auto-removal"

failed_job=failed-terminal-job
create_job '2000-01-01T00:00:00Z' "$failed_job" >/dev/null
assert_cron_has_job "$failed_job" "failed-job fixture starts with a line"
export RESUME_TEST_HARNESS_LOG="$scheduler_root/failed.args"
export RESUME_TEST_PROMPT_CAPTURE="$scheduler_root/failed.prompt"
export RESUME_TEST_CWD_CAPTURE="$scheduler_root/failed.cwd"
export RESUME_TEST_EXIT_CODE=1
export RESUME_TEST_OUTPUT='Fatal: session not found'
"$RESUME_JOB_CLI" run "$failed_job"
assert_equal failed "$(schedule_resume_read_status "$failed_job")" "terminal error marks failed"
assert_cron_lacks_job "$failed_job" "a failed job removes its own crontab line"
pass "terminal failure removes crontab line"

crontab_append_raw '* * * * * /nonexistent/run.sh # schedule-resume:ghost-no-dir'
"$RESUME_JOB_CLI" cleanup 0 >/dev/null
assert_cron_lacks_job ghost-no-dir "cleanup double-sweeps orphan crontab lines"
assert_foreign_survives "cleanup orphan sweep"
pass "cleanup sweeps orphan crontab lines"

cancel_job_id=cancel-preserves-state
create_job '2099-07-22T12:31:00Z' "$cancel_job_id" >/dev/null
cancel_dir="$RESUME_JOB_STATE_ROOT/$cancel_job_id"
assert_cron_has_job "$cancel_job_id" "cancel fixture starts with a line"
"$RESUME_JOB_CLI" cancel "$cancel_job_id"
assert_equal cancelled "$(schedule_resume_read_status "$cancel_job_id")" "cancel marks job terminal"
assert_file_exists "$cancel_dir/manifest.json" "cancel preserves manifest"
assert_file_exists "$cancel_dir/prompt.txt" "cancel preserves prompt"
assert_cron_lacks_job "$cancel_job_id" "cancel removes the crontab line"
assert_foreign_survives "cancel"
"$RESUME_JOB_CLI" cancel "$cancel_job_id"
assert_equal cancelled "$(schedule_resume_read_status "$cancel_job_id")" "repeated cancel stays terminal"
pass "cancel preserves state and removes the crontab line"

cancel_race_job=cancel-running-attempt
create_job '2000-01-01T00:00:00Z' "$cancel_race_job" >/dev/null
cancel_race_dir="$RESUME_JOB_STATE_ROOT/$cancel_race_job"
cancel_race_harness_barrier="$scheduler_root/cancel-race-harness"
mkdir -p "$cancel_race_harness_barrier"
export RESUME_TEST_HARNESS_LOG="$scheduler_root/cancel-race.args"
export RESUME_TEST_PROMPT_CAPTURE="$scheduler_root/cancel-race.prompt"
export RESUME_TEST_CWD_CAPTURE="$scheduler_root/cancel-race.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
export RESUME_TEST_HARNESS_BARRIER="$cancel_race_harness_barrier"
"$RESUME_JOB_CLI" run "$cancel_race_job" &
cancel_race_runner_pid=$!
cancel_race_wait_count=0
while ! find "$cancel_race_harness_barrier" -name 'launched.*' -type f | grep -q .; do
  cancel_race_wait_count=$((cancel_race_wait_count + 1))
  [ "$cancel_race_wait_count" -lt 500 ] || fail "running attempt did not launch"
  /bin/sleep 0.01
done
# The running attempt now holds the job lock. Cancel must remove the crontab
# line immediately, then block on the held attempt lock until the runner exits.
(
  if "$RESUME_JOB_CLI" cancel "$cancel_race_job" >"$scheduler_root/cancel-race.stdout" 2>"$scheduler_root/cancel-race.stderr"; then
    printf '0\n' >"$scheduler_root/cancel-race.result"
  else
    printf '%s\n' "$?" >"$scheduler_root/cancel-race.result"
  fi
) &
cancel_race_cancel_pid=$!
# The removed crontab line is the observable signal that cancel has passed its
# scheduler work and is now blocking on the attempt lock the runner still holds.
cancel_race_wait_count=0
while cron_has_job "$cancel_race_job"; do
  cancel_race_wait_count=$((cancel_race_wait_count + 1))
  [ "$cancel_race_wait_count" -lt 500 ] || fail "cancel did not remove the crontab line"
  /bin/sleep 0.01
done
assert_path_not_exists "$scheduler_root/cancel-race.result" "cancel must wait while the attempt owns the lock"
touch "$cancel_race_harness_barrier/release"
wait "$cancel_race_runner_pid"
wait "$cancel_race_cancel_pid"
unset RESUME_TEST_HARNESS_BARRIER
assert_equal 0 "$(cat "$scheduler_root/cancel-race.result")" "cancel succeeds after the attempt completes"
assert_equal cancelled "$(schedule_resume_read_status "$cancel_race_job")" "runner cannot overwrite serialized cancellation"
assert_equal success "$(jq -r '.last_classification' "$cancel_race_dir/status.json")" "cancellation preserves attempt fields"
assert_cron_lacks_job "$cancel_race_job" "cancel leaves no crontab line after serialized completion"
pass "cancel serializes with a running attempt"

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
  [ "$cancel_pid_wait_count" -lt 500 ] || fail "cancellation did not reach the PID ownership barrier"
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
assert_file_exists "$cleanup_old_dir/status.json" "lock error preserves terminal state"

cleanup_crontab_failure=a-cleanup-crontab-failure
create_job '2099-07-22T12:36:00Z' "$cleanup_crontab_failure" >/dev/null
cleanup_crontab_failure_dir="$RESUME_JOB_STATE_ROOT/$cleanup_crontab_failure"
cleanup_crontab_failure_status=$(jq '.status = "failed" | .last_finished_at = "2000-01-01T00:00:00Z" | .next_attempt_at = null' "$cleanup_crontab_failure_dir/status.json")
schedule_resume_write_status "$cleanup_crontab_failure" "$cleanup_crontab_failure_status"
export RESUME_TEST_CRONTAB_INSTALL_FAIL=5
if "$RESUME_JOB_CLI" cleanup 30 >"$scheduler_root/cleanup-crontab-error.stdout" 2>"$scheduler_root/cleanup-crontab-error.stderr"; then
  fail "cleanup must propagate an unexpected crontab removal failure"
fi
unset RESUME_TEST_CRONTAB_INSTALL_FAIL
assert_file_exists "$cleanup_crontab_failure_dir/status.json" "crontab failure preserves job state"

"$RESUME_JOB_CLI" cleanup 30 >"$scheduler_root/cleanup.stdout" 2>"$scheduler_root/cleanup.stderr"
assert_path_not_exists "$cleanup_old_dir" "cleanup removes old terminal job state"
assert_cron_lacks_job "$cleanup_old" "cleanup removes the terminal job's crontab line"
assert_file_exists "$cleanup_locked_dir/status.json" "cleanup preserves live-locked terminal job"
grep -Fq "cleanup skipped job $cleanup_locked: lock is held" "$scheduler_root/cleanup.stderr" || fail "cleanup reports lock contention"
assert_file_exists "$RESUME_JOB_STATE_ROOT/$cleanup_active/status.json" "cleanup preserves active job"
assert_file_exists "$malformed_dir/status.json" "cleanup preserves malformed job"
assert_file_exists "$RESUME_JOB_STATE_ROOT/cleanup-symlink-job/marker.txt" "cleanup preserves symlink entry target"
assert_file_exists "$cleanup_external/marker.txt" "cleanup leaves external symlink target untouched"
assert_foreign_survives "cleanup"
kill "$cleanup_lock_owner"
wait "$cleanup_lock_owner" 2>/dev/null || :
schedule_resume_release_lock "$cleanup_locked_dir" "$cleanup_lock_owner"
pass "safe retention cleanup"

rollback_job=rollback-install-failure
export RESUME_TEST_CRONTAB_INSTALL_FAIL=7
assert_command_fails "create reports crontab install failure" create_job '2099-07-22T12:34:00Z' "$rollback_job"
unset RESUME_TEST_CRONTAB_INSTALL_FAIL
assert_path_not_exists "$RESUME_JOB_STATE_ROOT/$rollback_job" "failed create removes only newly created state"
assert_cron_lacks_job "$rollback_job" "failed create leaves no crontab line"
assert_file_exists "$RESUME_JOB_STATE_ROOT/$cleanup_active/status.json" "failed create preserves other jobs"
assert_foreign_survives "create rollback"
pass "create rollback scope"

"$RESUME_JOB_CLI" list >"$scheduler_root/list-output"
grep -Eq "^$cleanup_active[[:space:]]" "$scheduler_root/list-output" || fail "list must include active job state"

crontab_append_raw '* * * * * /nonexistent/run.sh # schedule-resume:doctor-orphan'
"$RESUME_JOB_CLI" doctor >"$scheduler_root/doctor.stdout" 2>"$scheduler_root/doctor.stderr"
grep -Fq "$cleanup_active  [live:" "$scheduler_root/doctor.stdout" || fail "doctor must list live jobs with status"
grep -Fq 'doctor-orphan  [ORPHAN' "$scheduler_root/doctor.stdout" || fail "doctor must flag orphan lines"
grep -Fq "crontab -l | grep -v '# schedule-resume:' | crontab -" "$scheduler_root/doctor.stdout" || fail "doctor must print the purge command"
assert_cron_lacks_job doctor-orphan "doctor prunes orphan crontab lines"
assert_foreign_survives "doctor"
pass "doctor lists and prunes crontab entries"

# --- Liveness guard integration: active target defers, idle/absent resumes ---
gate_sessions="$scheduler_root/gate-sessions"

create_claude_job() {
  "$RESUME_JOB_CLI" create \
    --target-harness claude \
    --session-id "$1" \
    --project-dir "$scheduler_root/project" \
    --prompt-file "$prompt_source" \
    --schedule-type calendar \
    --first-attempt-at '2000-01-01T00:00:00Z' \
    --retry-interval-seconds 300 \
    --retry-policy until-completed \
    --completion-policy session-exits-zero \
    --permissions-mode full-auto \
    --job-id "$2"
}

write_gate_session() {
  jq -n --argjson pid "$1" --arg sid "$2" --arg status "$3" \
    '{pid: $pid, sessionId: $sid, cwd: "/x", kind: "interactive", status: $status, updatedAt: 0, statusUpdatedAt: 0}' \
    >"$4/$1.json"
}

gate_active_job=liveness-active-defers
gate_active_dir="$RESUME_JOB_STATE_ROOT/$gate_active_job"
gate_active_sessions="$gate_sessions/active"
mkdir -p "$gate_active_sessions"
/bin/sleep 30 &
gate_active_pid=$!
write_gate_session "$gate_active_pid" liveness-active-session busy "$gate_active_sessions"
create_claude_job liveness-active-session "$gate_active_job" >/dev/null

gate_active_args="$scheduler_root/gate-active.args"
rm -f "$gate_active_args"
export RESUME_TEST_HARNESS_LOG="$gate_active_args"
export RESUME_TEST_PROMPT_CAPTURE="$scheduler_root/gate-active.prompt"
export RESUME_TEST_CWD_CAPTURE="$scheduler_root/gate-active.cwd"
export SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR="$gate_active_sessions"
schedule_resume_run_attempt "$gate_active_job"
assert_path_not_exists "$gate_active_args" "active session defers without launching the adapter"
assert_equal scheduled "$(schedule_resume_read_status "$gate_active_job")" "deferral keeps the job scheduled"
assert_equal 0 "$(jq -r '.attempt_count' "$gate_active_dir/status.json")" "deferral spends no attempt"
assert_equal 1 "$(jq -r '.defer_count' "$gate_active_dir/status.json")" "deferral increments defer_count"
assert_equal deferred_session_active "$(jq -r '.last_classification' "$gate_active_dir/status.json")" "record the deferral classification"
[ "$(jq -r '.last_deferred_at' "$gate_active_dir/status.json")" != null ] || fail "deferral records last_deferred_at"
[ "$(jq -r '.next_attempt_at' "$gate_active_dir/status.json")" != null ] || fail "deferral re-arms next_attempt_at"
assert_path_not_exists "$gate_active_dir/attempts" "deferral creates no attempt artifacts"
# A second poll while the session is still busy defers again, no attempt spent.
schedule_resume_run_attempt "$gate_active_job"
assert_equal 2 "$(jq -r '.defer_count' "$gate_active_dir/status.json")" "consecutive deferrals accumulate"
assert_equal 0 "$(jq -r '.attempt_count' "$gate_active_dir/status.json")" "repeated deferral still spends no attempt"
unset SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR
kill "$gate_active_pid" 2>/dev/null || :
wait "$gate_active_pid" 2>/dev/null || :

"$RESUME_JOB_CLI" list >"$scheduler_root/gate-list.out"
grep -Eq "^$gate_active_job[[:space:]]" "$scheduler_root/gate-list.out" || fail "list includes the deferring job"
grep -Fq 'holding on active target session' "$scheduler_root/gate-list.out" || fail "list surfaces the holding-on-active-session state"
"$RESUME_JOB_CLI" status "$gate_active_job" >"$scheduler_root/gate-status.out"
grep -Fq deferred_session_active "$scheduler_root/gate-status.out" || fail "status surfaces the deferral classification"
grep -Fq defer_count "$scheduler_root/gate-status.out" || fail "status surfaces defer_count"
pass "liveness guard defers on an active target session"

gate_idle_job=liveness-idle-resumes
gate_idle_dir="$RESUME_JOB_STATE_ROOT/$gate_idle_job"
gate_idle_sessions="$gate_sessions/idle"
mkdir -p "$gate_idle_sessions"
/bin/sleep 30 &
gate_idle_pid=$!
write_gate_session "$gate_idle_pid" liveness-idle-session idle "$gate_idle_sessions"
create_claude_job liveness-idle-session "$gate_idle_job" >/dev/null
gate_idle_args="$scheduler_root/gate-idle.args"
rm -f "$gate_idle_args"
export RESUME_TEST_HARNESS_LOG="$gate_idle_args"
export RESUME_TEST_PROMPT_CAPTURE="$scheduler_root/gate-idle.prompt"
export RESUME_TEST_CWD_CAPTURE="$scheduler_root/gate-idle.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
export SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR="$gate_idle_sessions"
schedule_resume_run_attempt "$gate_idle_job"
unset SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR
assert_file_exists "$gate_idle_args" "idle session resumes and launches the adapter"
assert_equal completed "$(schedule_resume_read_status "$gate_idle_job")" "idle resume runs a normal attempt"
assert_equal 1 "$(jq -r '.attempt_count' "$gate_idle_dir/status.json")" "idle resume spends an attempt"
assert_equal success "$(jq -r '.last_classification' "$gate_idle_dir/status.json")" "idle resume classifies normally"
kill "$gate_idle_pid" 2>/dev/null || :
wait "$gate_idle_pid" 2>/dev/null || :
pass "liveness guard resumes on an idle target session"

gate_absent_job=liveness-absent-resumes
gate_absent_dir="$RESUME_JOB_STATE_ROOT/$gate_absent_job"
gate_absent_sessions="$gate_sessions/absent"
mkdir -p "$gate_absent_sessions"
create_claude_job liveness-absent-session "$gate_absent_job" >/dev/null
gate_absent_args="$scheduler_root/gate-absent.args"
rm -f "$gate_absent_args"
export RESUME_TEST_HARNESS_LOG="$gate_absent_args"
export RESUME_TEST_PROMPT_CAPTURE="$scheduler_root/gate-absent.prompt"
export RESUME_TEST_CWD_CAPTURE="$scheduler_root/gate-absent.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
export SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR="$gate_absent_sessions"
schedule_resume_run_attempt "$gate_absent_job"
unset SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR
assert_file_exists "$gate_absent_args" "absent session resumes and launches the adapter"
assert_equal completed "$(schedule_resume_read_status "$gate_absent_job")" "absent resume runs a normal attempt"
assert_equal 1 "$(jq -r '.attempt_count' "$gate_absent_dir/status.json")" "absent resume spends an attempt"
pass "liveness guard resumes on an absent target session"
