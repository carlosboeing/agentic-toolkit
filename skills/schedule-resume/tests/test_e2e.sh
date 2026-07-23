#!/bin/sh

RESUME_JOB_CLI="$TESTS_DIR/../scripts/resume-job.sh"
e2e_root="$TEST_TMPDIR/e2e"
mkdir -p "$e2e_root/project" "$e2e_root/bin" "$e2e_root/target-barrier"

cat >"$e2e_root/bin/claude" <<'EOF'
#!/bin/sh
set -eu

printf '%s\n' "$*" >>"$RESUME_E2E_INVOCATIONS"
if [ "${RESUME_E2E_MODE:-retry}" = retry ]; then
  if [ -n "${RESUME_E2E_BARRIER:-}" ]; then
    touch "$RESUME_E2E_BARRIER/launched.$$"
    while [ ! -e "$RESUME_E2E_BARRIER/release" ]; do sleep 0.01; done
  fi
  printf '%s\n' 'Usage quota exceeded. Retry after reset.'
  exit 1
elif [ "${RESUME_E2E_MODE:-retry}" = incomplete ]; then
  printf '%s\n' 'Still waiting on the build; will continue next attempt.'
  exit 0
elif [ "${RESUME_E2E_MODE:-retry}" = sentinel ]; then
  printf '%s\n' 'SCHEDULE_RESUME_TASK_COMPLETE'
  exit 0
fi
printf '%s\n' 'completed normally'
EOF
chmod 700 "$e2e_root/bin/claude"
export PATH="$e2e_root/bin:$TESTS_DIR/fixtures/bin:$PATH"

prompt_file="$e2e_root/prompt.md"
printf '%s\n' 'Continue the session and preserve this exact prompt.' >"$prompt_file"
job_id=e2e-lifecycle-job
rm -f "$RESUME_TEST_CRONTAB_FILE"
e2e_cron_has() { [ -f "$RESUME_TEST_CRONTAB_FILE" ] && grep -q -- "# schedule-resume:$1\$" "$RESUME_TEST_CRONTAB_FILE"; }
export RESUME_E2E_INVOCATIONS="$e2e_root/invocations.log"
: >"$RESUME_E2E_INVOCATIONS"
export RESUME_E2E_MODE=retry
export RESUME_E2E_BARRIER="$e2e_root/target-barrier"

created_job=$("$RESUME_JOB_CLI" create \
  --target-harness claude \
  --session-id e2e-session \
  --project-dir "$e2e_root/project" \
  --prompt-file "$prompt_file" \
  --schedule-type calendar \
  --first-attempt-at '2000-01-01T00:00:00Z' \
  --retry-interval-seconds 1 \
  --retry-policy until-completed \
  --completion-policy session-exits-zero \
  --permissions-mode full-auto \
  --job-id "$job_id")
assert_equal "$job_id" "$created_job" "create E2E job"

"$RESUME_JOB_CLI" run "$job_id" &
first_pid=$!
wait_count=0
while ! find "$e2e_root/target-barrier" -name 'launched.*' -type f | grep -q .; do
  wait_count=$((wait_count + 1))
  [ "$wait_count" -lt 200 ] || fail "E2E target did not launch"
  sleep 0.01
done
"$RESUME_JOB_CLI" run "$job_id" &
second_pid=$!
wait "$second_pid"
touch "$e2e_root/target-barrier/release"
wait "$first_pid"

assert_equal 1 "$(wc -l <"$RESUME_E2E_INVOCATIONS" | tr -d ' ')" "concurrent runs invoke target once"
job_dir="$RESUME_JOB_STATE_ROOT/$job_id"
assert_equal retrying "$(jq -r '.status' "$job_dir/status.json")" "retryable result persists"
assert_equal 1 "$(jq -r '.attempt_count' "$job_dir/status.json")" "record first attempt"
assert_file_exists "$job_dir/attempts/1/stdout.log" "preserve first attempt stdout"
assert_file_exists "$job_dir/attempts/1/stderr.log" "preserve first attempt stderr"
e2e_cron_has "$job_id" || fail "a retrying job keeps its crontab line"

export RESUME_E2E_MODE=success
jq '.next_attempt_at = "2000-01-01T00:00:00Z"' "$job_dir/status.json" >"$e2e_root/status.tmp"
mv "$e2e_root/status.tmp" "$job_dir/status.json"
"$RESUME_JOB_CLI" run "$job_id"
assert_equal completed "$(jq -r '.status' "$job_dir/status.json")" "successful retry completes"
assert_equal 2 "$(jq -r '.attempt_count' "$job_dir/status.json")" "record second attempt"
assert_file_exists "$job_dir/attempts/2/stdout.log" "preserve second attempt stdout"
if e2e_cron_has "$job_id"; then fail "a completed job auto-removes its crontab line"; fi
invocations_after_success=$(wc -l <"$RESUME_E2E_INVOCATIONS" | tr -d ' ')
"$RESUME_JOB_CLI" run "$job_id"
assert_equal "$invocations_after_success" "$(wc -l <"$RESUME_E2E_INVOCATIONS" | tr -d ' ')" "completed job is a no-op"

"$RESUME_JOB_CLI" cleanup 0
assert_path_not_exists "$job_dir" "cleanup removes terminal job state"
if e2e_cron_has "$job_id"; then fail "no crontab line remains after the lifecycle"; fi
pass "end-to-end lifecycle"

sentinel_job_id=e2e-sentinel-job
export RESUME_E2E_MODE=incomplete
created_sentinel_job=$("$RESUME_JOB_CLI" create \
  --target-harness claude \
  --session-id e2e-sentinel-session \
  --project-dir "$e2e_root/project" \
  --prompt-file "$prompt_file" \
  --schedule-type calendar \
  --first-attempt-at '2000-01-01T00:00:00Z' \
  --retry-interval-seconds 1 \
  --retry-policy until-completed \
  --completion-policy sentinel-output \
  --permissions-mode full-auto \
  --job-id "$sentinel_job_id")
assert_equal "$sentinel_job_id" "$created_sentinel_job" "create sentinel-output E2E job"
sentinel_job_dir="$RESUME_JOB_STATE_ROOT/$sentinel_job_id"

"$RESUME_JOB_CLI" run "$sentinel_job_id"
assert_equal retrying "$(jq -r '.status' "$sentinel_job_dir/status.json")" "exit zero without the sentinel reschedules"
assert_equal incomplete_retryable "$(jq -r '.last_classification' "$sentinel_job_dir/status.json")" "classify missing sentinel as incomplete"

export RESUME_E2E_MODE=sentinel
jq '.next_attempt_at = "2000-01-01T00:00:00Z"' "$sentinel_job_dir/status.json" >"$e2e_root/sentinel-status.tmp"
mv "$e2e_root/sentinel-status.tmp" "$sentinel_job_dir/status.json"
"$RESUME_JOB_CLI" run "$sentinel_job_id"
assert_equal completed "$(jq -r '.status' "$sentinel_job_dir/status.json")" "sentinel line completes the job"
assert_equal success "$(jq -r '.last_classification' "$sentinel_job_dir/status.json")" "classify sentinel line as success"
if e2e_cron_has "$sentinel_job_id"; then fail "sentinel completion auto-removes the crontab line"; fi

"$RESUME_JOB_CLI" cleanup 0
assert_path_not_exists "$sentinel_job_dir" "cleanup removes sentinel job state"
pass "sentinel-output completion policy end-to-end"
