#!/bin/sh

. "$LIB_DIR/common.sh"
. "$LIB_DIR/state.sh"
. "$LIB_DIR/lock.sh"
. "$LIB_DIR/adapters.sh"

execution_root="$TEST_TMPDIR/execution"
mkdir -p "$execution_root/project"
execution_root=$(CDPATH='' cd -- "$execution_root" && pwd)
prompt_file="$execution_root/prompt.md"
printf '%s\n' 'Say "hello" to the agent.' 'Keep $HOME; `uname`; a b; * ? [x] untouched.' 'Final line.' >"$prompt_file"
expected_prompt="$execution_root/expected-prompt.md"
cp "$prompt_file" "$expected_prompt"
printf '\n' >>"$prompt_file"
printf '\n' >>"$expected_prompt"

assert_adapter() {
  adapter_name=$1
  expected_arguments=$2
  export RESUME_TEST_HARNESS_LOG="$execution_root/$adapter_name.args"
  export RESUME_TEST_PROMPT_CAPTURE="$execution_root/$adapter_name.prompt"
  export RESUME_TEST_CWD_CAPTURE="$execution_root/$adapter_name.cwd"
  export RESUME_TEST_EXIT_CODE=0
  export RESUME_TEST_OUTPUT='adapter success'
  adapter_harness=${adapter_name#schedule_resume_execute_}

  "$adapter_name" "$TESTS_DIR/fixtures/bin/$adapter_harness" 'session id;$HOME' "$execution_root/project" "$prompt_file" >"$execution_root/$adapter_name.stdout" 2>"$execution_root/$adapter_name.stderr"

  assert_equal "$expected_arguments" "$(jq -c . "$RESUME_TEST_HARNESS_LOG")" "$adapter_name arguments"
  cmp -s "$expected_prompt" "$RESUME_TEST_PROMPT_CAPTURE" || fail "$adapter_name must preserve exact prompt bytes"
  assert_equal "$execution_root/project" "$(cat "$RESUME_TEST_CWD_CAPTURE")" "$adapter_name project directory"
  pass "$adapter_name command and prompt safety"
}

assert_adapter schedule_resume_execute_claude '["--resume","session id;$HOME","--dangerously-skip-permissions","--print"]'
assert_adapter schedule_resume_execute_agy '["--conversation","session id;$HOME","--dangerously-skip-permissions","--print"]'
assert_adapter schedule_resume_execute_codex '["exec","resume","--dangerously-bypass-approvals-and-sandbox","session id;$HOME","-"]'

classification_output="$execution_root/classification.log"
assert_classification() {
  expected=$1
  exit_code=$2
  message=$3
  printf '%s\n' "$message" >"$classification_output"
  assert_equal "$expected" "$(classify_result "$exit_code" "$classification_output")" "classify $expected"
}

assert_classification success 0 'completed normally'
assert_classification quota_retryable 1 'Usage quota exceeded. Retry after the reset.'
assert_classification quota_retryable 1 "You've hit your limit · resets at 5pm"
assert_classification quota_retryable 1 "You've hit your usage limit. Try again later."
assert_classification availability_retryable 1 'Service temporarily unavailable, try again later.'
assert_classification transient_retryable 1 'API Error: The operation timed out.'
assert_classification transient_retryable 1 'Request timed out while contacting the API.'
assert_classification transient_retryable 1 'API Error: Connection error.'
assert_classification transient_retryable 1 'fetch failed'
assert_classification transient_retryable 1 'Error: read ECONNRESET'
assert_classification transient_retryable 1 'API Error: 502 Bad Gateway'
assert_classification transient_retryable 1 'API Error: 529 {"type":"overloaded_error","message":"Overloaded"}'
assert_classification authentication_terminal 1 'Authentication failed: please log in.'
assert_classification session_terminal 1 'Session not found for the supplied identifier.'
assert_classification permission_terminal 1 'Permission denied by sandbox policy.'
assert_classification failure_terminal 17 'Unexpected ordinary failure.'
assert_classification failure_terminal 1 'temporary file cleanup failed'
assert_classification failure_terminal 1 'quota test failed'
assert_classification failure_terminal 1 'AssertionError: expected 500 to equal 200'
assert_classification failure_terminal 1 'AssertionError: expected 502 to equal 200'
pass "result classification"

lock_job_id=lock-test-job
lock_job_dir="$RESUME_JOB_STATE_ROOT/$lock_job_id"
mkdir -p "$lock_job_dir"
sleep 30 &
live_pid=$!
mkdir "$lock_job_dir/lock"
printf '%s\n' "$live_pid" >"$lock_job_dir/lock/pid"
printf '%s\n' '2026-07-22T12:00:00+10:00' >"$lock_job_dir/lock/started_at"
assert_command_fails "report a live lock without replacing it" schedule_resume_acquire_lock "$lock_job_dir" "$$"
assert_equal "$live_pid" "$(cat "$lock_job_dir/lock/pid")" "preserve live lock"
kill "$live_pid"
wait "$live_pid" 2>/dev/null || :
schedule_resume_acquire_lock "$lock_job_dir" "$$"
assert_equal "$$" "$(cat "$lock_job_dir/lock/pid")" "replace stale lock"
schedule_resume_release_lock "$lock_job_dir" "$$"
assert_path_not_exists "$lock_job_dir/lock" "release owned lock"
mkdir "$lock_job_dir/lock"
printf '%s\n' 'not-a-pid' >"$lock_job_dir/lock/pid"
printf '%s\n' '2026-07-22T12:00:00+10:00' >"$lock_job_dir/lock/started_at"
schedule_resume_acquire_lock "$lock_job_dir" "$$"
assert_equal "$$" "$(cat "$lock_job_dir/lock/pid")" "replace invalid lock PID"
schedule_resume_release_lock "$lock_job_dir" "$$"
assert_path_not_exists "$lock_job_dir/lock" "release replacement lock"
pass "live and stale locks"

lockf_error_job_dir="$RESUME_JOB_STATE_ROOT/lockf-error-job"
mkdir -p "$lockf_error_job_dir"
export RESUME_JOB_LOCKF="$TESTS_DIR/fixtures/bin/lockf-error"
if schedule_resume_acquire_lock "$lockf_error_job_dir" "$$" >"$execution_root/lockf-error.stdout" 2>"$execution_root/lockf-error.stderr"; then
  fail "non-contention lockf failure must not acquire"
else
  lockf_error_result=$?
fi
unset RESUME_JOB_LOCKF
assert_equal 69 "$lockf_error_result" "propagate non-contention lockf failure"
grep -q 'lockf.*69' "$execution_root/lockf-error.stderr" || fail "diagnose non-contention lockf failure"
pass "lockf error propagation"

guard_job_dir="$RESUME_JOB_STATE_ROOT/guard-contention-job"
guard_barrier="$execution_root/guard-contention-barrier"
mkdir -p "$guard_job_dir" "$guard_barrier"
export RESUME_TEST_MAIN_CLAIM_BARRIER="$guard_barrier"
export RESUME_TEST_MAIN_CLAIM_TARGET="$guard_job_dir/lock"
export RESUME_TEST_MAIN_CLAIM_ACTOR=A
(
  export RESUME_TEST_ACTOR=A
  if schedule_resume_acquire_lock "$guard_job_dir" "$$"; then
    printf '0\n' >"$guard_barrier/result-A"
  else
    printf '%s\n' "$?" >"$guard_barrier/result-A"
  fi
) &
guard_pid_a=$!
guard_wait_count=0
while [ ! -e "$guard_barrier/before-main-claim" ]; do
  guard_wait_count=$((guard_wait_count + 1))
  [ "$guard_wait_count" -lt 500 ] || fail "publisher did not pause before main lock claim"
  /bin/sleep 0.01
done
(
  export RESUME_TEST_ACTOR=B
  if schedule_resume_acquire_lock "$guard_job_dir" "$$"; then
    printf '0\n' >"$guard_barrier/result-B"
  else
    printf '%s\n' "$?" >"$guard_barrier/result-B"
  fi
) &
guard_pid_b=$!
wait "$guard_pid_b"
touch "$guard_barrier/allow-main-claim"
wait "$guard_pid_a"
guard_result_a=$(cat "$guard_barrier/result-A")
guard_result_b=$(cat "$guard_barrier/result-B")
assert_equal 0 "$guard_result_a" "guard holder must acquire main lock"
assert_equal 75 "$guard_result_b" "guard contender must return busy"
unset RESUME_TEST_MAIN_CLAIM_BARRIER RESUME_TEST_MAIN_CLAIM_TARGET RESUME_TEST_MAIN_CLAIM_ACTOR
schedule_resume_release_lock "$guard_job_dir" "$$"
pass "lockf guard contention"

crash_job_dir="$RESUME_JOB_STATE_ROOT/guard-crash-job"
crash_barrier="$execution_root/guard-crash-barrier"
mkdir -p "$crash_job_dir" "$crash_barrier"
export RESUME_TEST_LOCK_PUBLISH_BARRIER="$crash_barrier"
export RESUME_TEST_LOCK_PUBLISH_TARGET="$crash_job_dir/lock"
export RESUME_TEST_LOCK_PUBLISH_ACTOR=A
(
  export RESUME_TEST_ACTOR=A
  schedule_resume_acquire_lock "$crash_job_dir" "$$"
) 2>"$crash_barrier/publisher.stderr" &
crash_publisher_pid=$!
crash_wait_count=0
while ! find "$crash_barrier" -name 'created.*' -type f | grep -q .; do
  crash_wait_count=$((crash_wait_count + 1))
  [ "$crash_wait_count" -lt 500 ] || fail "publisher did not pause before PID publication"
  /bin/sleep 0.01
done
crash_fixture_pid=$(find "$crash_barrier" -name 'created.*' -type f | sed -n '1s/.*created\.//p')
kill "$crash_publisher_pid" 2>/dev/null || :
kill "$crash_fixture_pid" 2>/dev/null || :
wait "$crash_publisher_pid" 2>/dev/null || :
crash_wait_count=0
while [ ! -e "$crash_barrier/helper-released" ]; do
  crash_wait_count=$((crash_wait_count + 1))
  [ "$crash_wait_count" -lt 500 ] || fail "publisher helper did not release inherited guard"
  /bin/sleep 0.01
done
unset RESUME_TEST_LOCK_PUBLISH_BARRIER RESUME_TEST_LOCK_PUBLISH_TARGET RESUME_TEST_LOCK_PUBLISH_ACTOR
if ! schedule_resume_acquire_lock "$crash_job_dir" "$$"; then
  fail "next caller must recover publisher crash before PID publication"
fi
schedule_resume_release_lock "$crash_job_dir" "$$"
pass "lockf guard crash release"

publication_job_dir="$RESUME_JOB_STATE_ROOT/lock-publication-job"
publication_barrier="$execution_root/lock-publication-barrier"
mkdir -p "$publication_job_dir" "$publication_barrier"
export RESUME_TEST_LOCK_PUBLISH_BARRIER="$publication_barrier"
export RESUME_TEST_LOCK_PUBLISH_TARGET="$publication_job_dir/lock"
(
  if schedule_resume_acquire_lock "$publication_job_dir" "$$"; then
    printf '0\n' >"$publication_barrier/result-1"
    publication_owner_wait_count=0
    while [ ! -e "$publication_barrier/allow-owner-exit" ]; do
      publication_owner_wait_count=$((publication_owner_wait_count + 1))
      [ "$publication_owner_wait_count" -lt 500 ] || exit 1
      /bin/sleep 0.01
    done
  else
    printf '%s\n' "$?" >"$publication_barrier/result-1"
  fi
) &
publication_pid_1=$!
publication_wait_count=0
while ! find "$publication_barrier" -name 'created.*' -type f | grep -q .; do
  publication_wait_count=$((publication_wait_count + 1))
  [ "$publication_wait_count" -lt 500 ] || fail "first lock acquisition did not enter publication barrier"
  /bin/sleep 0.01
done
(
  if schedule_resume_acquire_lock "$publication_job_dir" "$$"; then
    printf '0\n' >"$publication_barrier/result-2"
  else
    printf '%s\n' "$?" >"$publication_barrier/result-2"
  fi
) &
publication_pid_2=$!
publication_wait_count=0
while :; do
  publication_created_count=$(find "$publication_barrier" -name 'created.*' -type f | wc -l | tr -d ' ')
  if [ -e "$publication_barrier/result-2" ] || [ "$publication_created_count" -ge 2 ]; then
    break
  fi
  publication_wait_count=$((publication_wait_count + 1))
  [ "$publication_wait_count" -lt 500 ] || fail "second lock acquisition did not inspect publication window"
  /bin/sleep 0.01
done
touch "$publication_barrier/release"
publication_wait_count=0
while [ ! -e "$publication_barrier/result-2" ]; do
  publication_wait_count=$((publication_wait_count + 1))
  [ "$publication_wait_count" -lt 500 ] || fail "concurrent lock acquisition did not finish"
  /bin/sleep 0.01
done
touch "$publication_barrier/allow-owner-exit"
wait "$publication_pid_1"
wait "$publication_pid_2"
unset RESUME_TEST_LOCK_PUBLISH_BARRIER RESUME_TEST_LOCK_PUBLISH_TARGET
publication_result_1=$(cat "$publication_barrier/result-1")
publication_result_2=$(cat "$publication_barrier/result-2")
publication_successes=$(jq -n \
  --argjson first "$publication_result_1" \
  --argjson second "$publication_result_2" \
  '[ $first, $second ] | map(select(. == 0)) | length')
assert_equal 1 "$publication_successes" "allow exactly one owner during lock metadata publication"
publication_noops=$(jq -n \
  --argjson first "$publication_result_1" \
  --argjson second "$publication_result_2" \
  '[ $first, $second ] | map(select(. == 75)) | length')
assert_equal 1 "$publication_noops" "return the concurrent caller through the live-lock no-op path"
rm -f "$publication_job_dir/lock/pid" "$publication_job_dir/lock/started_at"
rmdir "$publication_job_dir/lock"
pass "lock metadata publication race"

attempt_job_id=attempt-success
attempt_job_dir="$RESUME_JOB_STATE_ROOT/$attempt_job_id"
attempt_manifest=$(jq -n \
  --arg job_id "$attempt_job_id" \
  --arg project_dir "$execution_root/project" \
  --arg prompt_file "$prompt_file" \
  '{
    job_id: $job_id,
    target_harness: "claude",
    harness_executable: $harness_executable,
    session_id: "session-success",
    project_dir: $project_dir,
    prompt_file: $prompt_file,
    schedule_type: "at",
    first_attempt_at: "2026-07-22T12:30:00+10:00",
    retry_interval_seconds: 300,
    retry_policy: "until-completed",
    completion_policy: "session-exits-zero",
    permissions_mode: "full-auto",
    created_at: "2026-07-22T12:00:00+10:00",
    status: "scheduled"
  }' --arg harness_executable "$TESTS_DIR/fixtures/bin/claude")

for terminal_status in completed failed cancelled; do
  terminal_noop_job_id="terminal-noop-$terminal_status"
  terminal_noop_job_dir="$RESUME_JOB_STATE_ROOT/$terminal_noop_job_id"
  terminal_noop_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$terminal_noop_job_id" '.job_id = $job_id')
  schedule_resume_create_job "$terminal_noop_manifest"
  terminal_noop_status=$(jq -n --arg status "$terminal_status" '{
    status: $status,
    attempt_count: 4,
    last_exit_code: 0,
    last_classification: "success",
    last_started_at: "2026-07-22T12:30:00+10:00",
    last_finished_at: "2026-07-22T12:31:00+10:00",
    next_attempt_at: null
  }')
  schedule_resume_write_status "$terminal_noop_job_id" "$terminal_noop_status"
  cp "$terminal_noop_job_dir/status.json" "$execution_root/$terminal_noop_job_id.status-before"
  rm -f "$execution_root/$terminal_noop_job_id.launch"
  export RESUME_TEST_HARNESS_LOG="$execution_root/$terminal_noop_job_id.launch"
  schedule_resume_run_attempt "$terminal_noop_job_id"
  cmp -s "$execution_root/$terminal_noop_job_id.status-before" "$terminal_noop_job_dir/status.json" ||
    fail "$terminal_status status must remain byte-identical"
  assert_path_not_exists "$terminal_noop_job_dir/attempts" "$terminal_status must not create attempt artifacts"
  assert_path_not_exists "$execution_root/$terminal_noop_job_id.launch" "$terminal_status must not launch target"
done
pass "terminal state no-op"

attempt_dir_failure_job_id=attempt-dir-failure
attempt_dir_failure_job_dir="$RESUME_JOB_STATE_ROOT/$attempt_dir_failure_job_id"
attempt_dir_failure_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$attempt_dir_failure_job_id" '.job_id = $job_id')
schedule_resume_create_job "$attempt_dir_failure_manifest"
export RESUME_TEST_FAIL_MKDIR_TARGET="$attempt_dir_failure_job_dir/attempts/1"
schedule_resume_run_attempt "$attempt_dir_failure_job_id" >/dev/null 2>&1 || :
unset RESUME_TEST_FAIL_MKDIR_TARGET
if [ "$(schedule_resume_read_status "$attempt_dir_failure_job_id")" = running ]; then
  fail "attempt directory failure must not strand running"
fi
pass "post-publication attempt directory failure"

final_write_failure_job_id=final-write-failure
final_write_failure_job_dir="$RESUME_JOB_STATE_ROOT/$final_write_failure_job_id"
final_write_failure_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$final_write_failure_job_id" '.job_id = $job_id')
schedule_resume_create_job "$final_write_failure_manifest"
export RESUME_TEST_HARNESS_LOG="$execution_root/final-write-failure.args"
export RESUME_TEST_PROMPT_CAPTURE="$execution_root/final-write-failure.prompt"
export RESUME_TEST_CWD_CAPTURE="$execution_root/final-write-failure.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
export RESUME_TEST_FAIL_FINAL_STATUS_WRITE_ONCE="$execution_root/final-write-failure.marker"
schedule_resume_run_attempt "$final_write_failure_job_id" >/dev/null 2>&1 || :
unset RESUME_TEST_FAIL_FINAL_STATUS_WRITE_ONCE
assert_equal failed "$(schedule_resume_read_status "$final_write_failure_job_id")" "final publication failure must finalize failed"
assert_equal failure_terminal "$(jq -r '.last_classification' "$final_write_failure_job_dir/status.json")" "classify final publication failure"
pass "final status publication failure"

orphan_job_id=attempt-orphan-recovery
orphan_job_dir="$RESUME_JOB_STATE_ROOT/$orphan_job_id"
orphan_barrier="$execution_root/attempt-orphan-barrier"
mkdir -p "$orphan_barrier"
orphan_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$orphan_job_id" '.job_id = $job_id')
schedule_resume_create_job "$orphan_manifest"
export RESUME_TEST_ATTEMPT_DIR_BARRIER="$orphan_barrier"
export RESUME_TEST_ATTEMPT_DIR_TARGET="$orphan_job_dir/attempts/1"
(schedule_resume_run_attempt "$orphan_job_id") 2>"$orphan_barrier/runner.stderr" &
orphan_launcher_pid=$!
orphan_wait_count=0
while ! find "$orphan_barrier" -name 'created.*' -type f | grep -q .; do
  orphan_wait_count=$((orphan_wait_count + 1))
  [ "$orphan_wait_count" -lt 500 ] || fail "attempt directory was not created at crash barrier"
  /bin/sleep 0.01
done
assert_equal running "$(schedule_resume_read_status "$orphan_job_id")" "publish running before attempt directory creation"
orphan_owner_pid=$(cat "$orphan_job_dir/lock/pid")
orphan_fixture_pid=$(find "$orphan_barrier" -name 'created.*' -type f | sed -n '1s/.*created\.//p')
kill -KILL "$orphan_owner_pid" 2>/dev/null || :
kill -KILL "$orphan_fixture_pid" 2>/dev/null || :
wait "$orphan_launcher_pid" 2>/dev/null || :
unset RESUME_TEST_ATTEMPT_DIR_BARRIER RESUME_TEST_ATTEMPT_DIR_TARGET
export RESUME_TEST_HARNESS_LOG="$execution_root/attempt-orphan-recovery.args"
export RESUME_TEST_PROMPT_CAPTURE="$execution_root/attempt-orphan-recovery.prompt"
export RESUME_TEST_CWD_CAPTURE="$execution_root/attempt-orphan-recovery.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
schedule_resume_run_attempt "$orphan_job_id"
assert_equal completed "$(schedule_resume_read_status "$orphan_job_id")" "recover orphan attempt directory on next invocation"
assert_equal 2 "$(jq -r '.attempt_count' "$orphan_job_dir/status.json")" "advance attempt count past orphan directory"
assert_file_exists "$orphan_job_dir/attempts/2/stdout.log" "create next attempt after orphan"
pass "orphan attempt directory crash recovery"

for publication_case in completed retrying; do
  publication_job_id="final-publication-$publication_case"
  publication_job_dir="$RESUME_JOB_STATE_ROOT/$publication_job_id"
  publication_signal_barrier="$execution_root/$publication_job_id-barrier"
  mkdir -p "$publication_signal_barrier"
  publication_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$publication_job_id" '.job_id = $job_id')
  schedule_resume_create_job "$publication_manifest"
  export RESUME_TEST_HARNESS_LOG="$execution_root/$publication_job_id.args"
  export RESUME_TEST_PROMPT_CAPTURE="$execution_root/$publication_job_id.prompt"
  export RESUME_TEST_CWD_CAPTURE="$execution_root/$publication_job_id.cwd"
  if [ "$publication_case" = completed ]; then
    export RESUME_TEST_EXIT_CODE=0
    export RESUME_TEST_OUTPUT='completed normally'
  else
    export RESUME_TEST_EXIT_CODE=1
    export RESUME_TEST_OUTPUT='Usage quota exceeded. Retry after reset.'
  fi
  export RESUME_TEST_FINAL_STATUS_BARRIER="$publication_signal_barrier"
  (schedule_resume_run_attempt "$publication_job_id") 2>"$publication_signal_barrier/runner.stderr" &
  publication_launcher_pid=$!
  publication_wait_count=0
  while [ ! -e "$publication_signal_barrier/published" ]; do
    publication_wait_count=$((publication_wait_count + 1))
    [ "$publication_wait_count" -lt 500 ] || fail "$publication_case final status was not published"
    /bin/sleep 0.01
  done
  assert_equal "$publication_case" "$(schedule_resume_read_status "$publication_job_id")" "publish $publication_case before signal"
  publication_owner_pid=$(cat "$publication_job_dir/lock/pid")
  if [ "$publication_case" = completed ]; then
    kill -TERM "$publication_owner_pid"
  else
    kill -HUP "$publication_owner_pid"
  fi
  touch "$publication_signal_barrier/release"
  wait "$publication_launcher_pid" 2>/dev/null || :
  unset RESUME_TEST_FINAL_STATUS_BARRIER
  assert_equal "$publication_case" "$(schedule_resume_read_status "$publication_job_id")" "preserve published $publication_case after signal"
  assert_equal "$([ "$publication_case" = completed ] && printf success || printf quota_retryable)" \
    "$(jq -r '.last_classification' "$publication_job_dir/status.json")" "preserve $publication_case classification"
done
pass "final publication signal race"

schedule_resume_create_job "$attempt_manifest"
export RESUME_TEST_HARNESS_LOG="$execution_root/attempt-success.args"
export RESUME_TEST_PROMPT_CAPTURE="$execution_root/attempt-success.prompt"
export RESUME_TEST_CWD_CAPTURE="$execution_root/attempt-success.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
schedule_resume_run_attempt "$attempt_job_id"
assert_equal completed "$(schedule_resume_read_status "$attempt_job_id")" "complete successful attempt"
assert_equal 1 "$(jq -r '.attempt_count' "$attempt_job_dir/status.json")" "increment attempt count"
assert_equal success "$(jq -r '.last_classification' "$attempt_job_dir/status.json")" "record success classification"
assert_file_exists "$attempt_job_dir/attempts/1/stdout.log" "capture stdout"
assert_file_exists "$attempt_job_dir/attempts/1/stderr.log" "capture stderr"
assert_path_not_exists "$attempt_job_dir/lock" "release attempt lock"
pass "successful attempt"

retry_job_id=attempt-retry
retry_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$retry_job_id" '.job_id = $job_id | .retry_interval_seconds = 1')
schedule_resume_create_job "$retry_manifest"
export RESUME_TEST_HARNESS_LOG="$execution_root/attempt-retry.args"
export RESUME_TEST_PROMPT_CAPTURE="$execution_root/attempt-retry.prompt"
export RESUME_TEST_CWD_CAPTURE="$execution_root/attempt-retry.cwd"
export RESUME_TEST_EXIT_CODE=1
export RESUME_TEST_OUTPUT='Usage quota exceeded. Retry after reset.'
retry_started_epoch=$(date +%s)
schedule_resume_run_attempt "$retry_job_id"
retry_finished_epoch=$(date +%s)
assert_equal retrying "$(schedule_resume_read_status "$retry_job_id")" "retry quota failure"
assert_equal quota_retryable "$(jq -r '.last_classification' "$RESUME_JOB_STATE_ROOT/$retry_job_id/status.json")" "record retry classification"
retry_next_attempt_at=$(jq -r '.next_attempt_at' "$RESUME_JOB_STATE_ROOT/$retry_job_id/status.json")
if [ "$retry_next_attempt_at" = null ]; then
  fail "retrying attempts must calculate next_attempt_at"
fi
retry_next_epoch=$(jq -nr --arg timestamp "$retry_next_attempt_at" '$timestamp | fromdateiso8601')
if [ "$retry_next_epoch" -lt "$((retry_started_epoch + 1))" ] ||
  [ "$retry_next_epoch" -gt "$((retry_finished_epoch + 1))" ]; then
  fail "retrying attempts must use retry_interval_seconds"
fi
pass "retryable attempt"

terminal_job_id=attempt-terminal
terminal_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$terminal_job_id" '.job_id = $job_id')
schedule_resume_create_job "$terminal_manifest"
export RESUME_TEST_HARNESS_LOG="$execution_root/attempt-terminal.args"
export RESUME_TEST_PROMPT_CAPTURE="$execution_root/attempt-terminal.prompt"
export RESUME_TEST_CWD_CAPTURE="$execution_root/attempt-terminal.cwd"
export RESUME_TEST_EXIT_CODE=1
export RESUME_TEST_OUTPUT='Authentication failed: please log in.'
schedule_resume_run_attempt "$terminal_job_id"
assert_equal failed "$(schedule_resume_read_status "$terminal_job_id")" "fail terminal attempt"
assert_equal authentication_terminal "$(jq -r '.last_classification' "$RESUME_JOB_STATE_ROOT/$terminal_job_id/status.json")" "record terminal classification"
assert_equal null "$(jq -r '.next_attempt_at' "$RESUME_JOB_STATE_ROOT/$terminal_job_id/status.json")" "do not schedule terminal retry"
pass "terminal attempt"

launch_job_id=attempt-single-launch
launch_job_dir="$RESUME_JOB_STATE_ROOT/$launch_job_id"
launch_barrier="$execution_root/single-launch-barrier"
mkdir -p "$launch_barrier"
launch_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$launch_job_id" '.job_id = $job_id')
schedule_resume_create_job "$launch_manifest"
export RESUME_TEST_HARNESS_LOG="$execution_root/single-launch.args"
export RESUME_TEST_PROMPT_CAPTURE="$execution_root/single-launch.prompt"
export RESUME_TEST_CWD_CAPTURE="$execution_root/single-launch.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
export RESUME_TEST_HARNESS_BARRIER="$launch_barrier"
schedule_resume_run_attempt "$launch_job_id" &
launch_pid_1=$!
launch_wait_count=0
while ! find "$launch_barrier" -name 'launched.*' -type f | grep -q .; do
  launch_wait_count=$((launch_wait_count + 1))
  [ "$launch_wait_count" -lt 500 ] || fail "first target did not launch"
  /bin/sleep 0.01
done
schedule_resume_run_attempt "$launch_job_id" &
launch_pid_2=$!
wait "$launch_pid_2"
launch_count=$(find "$launch_barrier" -name 'launched.*' -type f | wc -l | tr -d ' ')
assert_equal 1 "$launch_count" "launch exactly one target for concurrent attempts"
touch "$launch_barrier/release"
wait "$launch_pid_1"
unset RESUME_TEST_HARNESS_BARRIER
assert_equal completed "$(schedule_resume_read_status "$launch_job_id")" "complete single launched target"
assert_equal 1 "$(jq -r '.attempt_count' "$launch_job_dir/status.json")" "record one concurrent attempt"
pass "single target launch"

pid_crash_job_id=attempt-pid-crash
pid_crash_job_dir="$RESUME_JOB_STATE_ROOT/$pid_crash_job_id"
pid_crash_barrier="$execution_root/pid-crash-barrier"
mkdir -p "$pid_crash_barrier"
pid_crash_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$pid_crash_job_id" '.job_id = $job_id')
schedule_resume_create_job "$pid_crash_manifest"
export RESUME_TEST_HARNESS_LOG="$execution_root/pid-crash.args"
export RESUME_TEST_PROMPT_CAPTURE="$execution_root/pid-crash.prompt"
export RESUME_TEST_CWD_CAPTURE="$execution_root/pid-crash.cwd"
export RESUME_TEST_EXIT_CODE=0
export RESUME_TEST_OUTPUT='completed normally'
export RESUME_TEST_HARNESS_BARRIER="$pid_crash_barrier"
(schedule_resume_run_attempt "$pid_crash_job_id") 2>"$pid_crash_barrier/runner.stderr" &
pid_crash_launcher_pid=$!
pid_crash_wait_count=0
while ! find "$pid_crash_barrier" -name 'launched.*' -type f | grep -q .; do
  pid_crash_wait_count=$((pid_crash_wait_count + 1))
  [ "$pid_crash_wait_count" -lt 500 ] || fail "PID crash target did not launch"
  /bin/sleep 0.01
done
pid_crash_owner=$(cat "$pid_crash_job_dir/lock/pid")
if [ "$pid_crash_owner" = "$$" ]; then
  fail "main lock must record runner process rather than parent shell"
fi
pid_crash_harness_pid=$(find "$pid_crash_barrier" -name 'launched.*' -type f | sed -n '1s/.*launched\.//p')
kill -KILL "$pid_crash_owner" 2>/dev/null || :
kill -KILL "$pid_crash_harness_pid" 2>/dev/null || :
wait "$pid_crash_launcher_pid" 2>/dev/null || :
unset RESUME_TEST_HARNESS_BARRIER
if ! schedule_resume_acquire_lock "$pid_crash_job_dir" "$$"; then
  fail "recover crashed runner lock while parent remains alive"
fi
schedule_resume_release_lock "$pid_crash_job_dir" "$$"
pass "runner PID crash recovery"

concurrent_job_id=attempt-concurrent
concurrent_job_dir="$RESUME_JOB_STATE_ROOT/$concurrent_job_id"
concurrent_manifest=$(printf '%s\n' "$attempt_manifest" | jq --arg job_id "$concurrent_job_id" '.job_id = $job_id')
schedule_resume_create_job "$concurrent_manifest"
sleep 30 &
concurrent_live_pid=$!
mkdir "$concurrent_job_dir/lock"
printf '%s\n' "$concurrent_live_pid" >"$concurrent_job_dir/lock/pid"
printf '%s\n' '2026-07-22T12:00:00+10:00' >"$concurrent_job_dir/lock/started_at"
status_before=$(jq -c . "$concurrent_job_dir/status.json")
rm -f "$execution_root/concurrent-launch.args"
export RESUME_TEST_HARNESS_LOG="$execution_root/concurrent-launch.args"
schedule_resume_run_attempt "$concurrent_job_id"
assert_equal "$status_before" "$(jq -c . "$concurrent_job_dir/status.json")" "leave state unchanged for concurrent invocation"
assert_path_not_exists "$execution_root/concurrent-launch.args" "do not launch a concurrent target"
kill "$concurrent_live_pid"
wait "$concurrent_live_pid" 2>/dev/null || :
rm -f "$concurrent_job_dir/lock/pid" "$concurrent_job_dir/lock/started_at"
rmdir "$concurrent_job_dir/lock"
pass "concurrent attempt exits cleanly"
