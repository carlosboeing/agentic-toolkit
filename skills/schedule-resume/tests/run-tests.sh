#!/bin/sh
set -eu

TESTS_DIR=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
LIB_DIR=$(CDPATH='' cd -- "$TESTS_DIR/../scripts/lib" && pwd)
TEST_GROUP=${1:-all}
TEST_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/schedule-resume-tests.XXXXXX")
trap 'rm -rf "$TEST_TMPDIR"' EXIT HUP INT TERM

export HOME="$TEST_TMPDIR/home"
export RESUME_JOB_STATE_ROOT="$TEST_TMPDIR/state"
export RESUME_TEST_CRONTAB_FILE="$TEST_TMPDIR/crontab"
export PATH="$TESTS_DIR/fixtures/bin:$PATH"
mkdir -p "$HOME" "$RESUME_JOB_STATE_ROOT"

. "$TESTS_DIR/test_helpers.sh"

run_state_tests() {
  . "$LIB_DIR/common.sh"
  . "$LIB_DIR/state.sh"

  assert_equal "job-20260722_123000" "$(schedule_resume_validate_job_id 'job-20260722_123000')" "accept safe job IDs"
  assert_command_fails "reject empty job IDs" schedule_resume_validate_job_id ""
  assert_command_fails "reject job IDs with path separators" schedule_resume_validate_job_id "../escape"
  assert_command_fails "reject job IDs with a leading dot" schedule_resume_validate_job_id ".hidden"
  pass "job ID validation"

  job_id=job-20260722_123000
  job_dir="$RESUME_JOB_STATE_ROOT/$job_id"
  assert_equal "$job_dir" "$(schedule_resume_job_dir "$job_id")" "derive job directory"
  assert_equal "$job_dir/manifest.json" "$(schedule_resume_manifest_path "$job_id")" "derive manifest path"
  assert_equal "$job_dir/status.json" "$(schedule_resume_status_path "$job_id")" "derive status path"
  assert_command_fails "reject invalid IDs in manifest paths" schedule_resume_manifest_path "../escape"
  assert_command_fails "reject invalid IDs in status paths" schedule_resume_status_path "../escape"
  pass "job paths"

  manifest=$(jq -n \
    --arg job_id "$job_id" \
    '{
      job_id: $job_id,
      target_harness: "codex",
      harness_executable: "/usr/bin/true",
      session_id: "session-123",
      project_dir: "/tmp/example-project",
      prompt_file: "/tmp/example-prompt.md",
      schedule_type: "at",
      first_attempt_at: "2026-07-22T12:30:00+10:00",
      retry_interval_seconds: 300,
      retry_policy: "until-completed",
      completion_policy: "session-exits-zero",
      permissions_mode: "full-auto",
      created_at: "2026-07-22T12:00:00+10:00",
      status: "scheduled"
    }')

  schedule_resume_create_job "$manifest"
  assert_file_exists "$job_dir/manifest.json" "write manifest"
  assert_file_exists "$job_dir/status.json" "write initial status"
  assert_json_equal "$manifest" "$job_dir/manifest.json" "preserve the manifest contract"
  initial_status='{
    "status": "scheduled",
    "attempt_count": 0,
    "last_exit_code": null,
    "last_classification": null,
    "last_started_at": null,
    "last_finished_at": null,
    "next_attempt_at": "2026-07-22T12:30:00+10:00"
  }'
  assert_json_equal "$initial_status" "$job_dir/status.json" "initialize mutable execution state"
  assert_command_fails "do not overwrite an immutable manifest" schedule_resume_create_job "$manifest"
  pass "job creation"

  unexpected_manifest=$(printf '%s\n' "$manifest" | jq '.job_id = "job-with-extra-field" | .unexpected = true')
  assert_equal "true" "$(printf '%s\n' "$unexpected_manifest" | jq -r 'has("unexpected")')" "build an extra-field manifest fixture"
  assert_command_fails "reject manifest keys outside the contract" schedule_resume_create_job "$unexpected_manifest"
  pass "exact manifest key contract"

  for invalid_retry_interval in 1.5 0 -1; do
    invalid_interval_job_id="invalid-retry-${invalid_retry_interval}"
    invalid_interval_manifest=$(printf '%s\n' "$manifest" | jq \
      --arg job_id "$invalid_interval_job_id" \
      --argjson retry_interval_seconds "$invalid_retry_interval" \
      '.job_id = $job_id | .retry_interval_seconds = $retry_interval_seconds')
    assert_command_fails "reject retry interval '$invalid_retry_interval'" schedule_resume_create_job "$invalid_interval_manifest"
    assert_path_not_exists "$RESUME_JOB_STATE_ROOT/$invalid_interval_job_id" "do not create invalid retry interval job"
  done
  pass "positive integer retry interval contract"

  concurrent_job_id=concurrent-job
  concurrent_job_dir="$RESUME_JOB_STATE_ROOT/$concurrent_job_id"
  concurrent_manifest=$(jq --arg job_id "$concurrent_job_id" '.job_id = $job_id' "$job_dir/manifest.json")
  concurrent_barrier="$TEST_TMPDIR/concurrent-barrier"
  mkdir -p "$concurrent_barrier"
  export RESUME_TEST_MKDIR_BARRIER="$concurrent_barrier"
  export RESUME_TEST_MKDIR_TARGET="$concurrent_job_dir"
  (
    if schedule_resume_create_job "$concurrent_manifest"; then
      printf '0\n' >"$TEST_TMPDIR/concurrent-result-1"
    else
      printf '%s\n' "$?" >"$TEST_TMPDIR/concurrent-result-1"
    fi
  ) &
  concurrent_pid_1=$!
  (
    if schedule_resume_create_job "$concurrent_manifest"; then
      printf '0\n' >"$TEST_TMPDIR/concurrent-result-2"
    else
      printf '%s\n' "$?" >"$TEST_TMPDIR/concurrent-result-2"
    fi
  ) &
  concurrent_pid_2=$!
  wait "$concurrent_pid_1"
  wait "$concurrent_pid_2"
  unset RESUME_TEST_MKDIR_BARRIER RESUME_TEST_MKDIR_TARGET
  concurrent_result_1=$(jq -Rr 'tonumber' "$TEST_TMPDIR/concurrent-result-1")
  concurrent_result_2=$(jq -Rr 'tonumber' "$TEST_TMPDIR/concurrent-result-2")
  concurrent_successes=$(jq -n --argjson first "$concurrent_result_1" --argjson second "$concurrent_result_2" '[ $first, $second ] | map(select(. == 0)) | length')
  assert_equal "1" "$concurrent_successes" "allow exactly one concurrent creator"
  pass "atomic concurrent creation"

  failed_write_job_id=failed-status-write-job
  failed_write_job_dir="$RESUME_JOB_STATE_ROOT/$failed_write_job_id"
  failed_write_manifest=$(jq --arg job_id "$failed_write_job_id" '.job_id = $job_id' "$job_dir/manifest.json")
  export RESUME_TEST_FAIL_STATUS_WRITE_ONCE="$TEST_TMPDIR/failed-status-write.marker"
  assert_command_fails "report initial status publication failure" schedule_resume_create_job "$failed_write_manifest"
  unset RESUME_TEST_FAIL_STATUS_WRITE_ONCE
  assert_path_not_exists "$failed_write_job_dir" "remove a half-created job"
  schedule_resume_create_job "$failed_write_manifest"
  assert_file_exists "$failed_write_job_dir/manifest.json" "retry manifest publication"
  assert_file_exists "$failed_write_job_dir/status.json" "retry status publication"
  pass "failed creation cleanup and retry"

  attempt=0
  for status in scheduled running retrying completed failed cancelled; do
    attempt=$((attempt + 1))
    status_json=$(jq -n \
      --arg status "$status" \
      --argjson attempt_count "$attempt" \
      '{
        status: $status,
        attempt_count: $attempt_count,
        last_exit_code: 0,
        last_classification: "test",
        last_started_at: "2026-07-22T12:30:00+10:00",
        last_finished_at: "2026-07-22T12:31:00+10:00",
        next_attempt_at: null
      }')
    schedule_resume_write_status "$job_id" "$status_json"
    assert_equal "$status" "$(schedule_resume_read_status "$job_id")" "read '$status' state"
    assert_json_equal "$status_json" "$job_dir/status.json" "preserve '$status' execution state"
  done
  pass "approved state round trips"

  invalid_status=$(jq -n '{
    status: "paused",
    attempt_count: 6,
    last_exit_code: null,
    last_classification: null,
    last_started_at: null,
    last_finished_at: null,
    next_attempt_at: null
  }')
  assert_command_fails "reject unapproved states" schedule_resume_write_status "$job_id" "$invalid_status"
  assert_equal "cancelled" "$(schedule_resume_read_status "$job_id")" "preserve state after a rejected update"
  pass "state validation"

  incomplete_status='{"status":"running","attempt_count":7}'
  assert_command_fails "require every mutable execution field" schedule_resume_write_status "$job_id" "$incomplete_status"
  assert_equal "cancelled" "$(schedule_resume_read_status "$job_id")" "preserve state after an incomplete update"
  pass "mutable execution field contract"

  if find "$job_dir" -type f ! -name manifest.json ! -name status.json | grep -q .; then
    fail "atomic writes must not leave temporary files"
  fi
  pass "atomic file cleanup"

  preservation_manifest=$(jq '.job_id = "caller-variable-preservation-job"' "$RESUME_JOB_STATE_ROOT/job-20260722_123000/manifest.json")
  job_id=caller-job-id
  job_dir=caller-job-dir
  status=caller-status
  manifest=caller-manifest
  destination=caller-destination
  temporary=caller-temporary
  schedule_resume_create_job "$preservation_manifest"
  assert_equal "caller-job-id" "$job_id" "preserve caller job_id"
  assert_equal "caller-job-dir" "$job_dir" "preserve caller job_dir"
  assert_equal "caller-status" "$status" "preserve caller status"
  assert_equal "caller-manifest" "$manifest" "preserve caller manifest"
  assert_equal "caller-destination" "$destination" "preserve caller destination"
  assert_equal "caller-temporary" "$temporary" "preserve caller temporary"
  pass "caller variable preservation"
}

run_execution_tests() {
  . "$TESTS_DIR/test_execution.sh"
}

run_liveness_tests() {
  . "$TESTS_DIR/test_liveness.sh"
}

run_scheduler_tests() {
  . "$TESTS_DIR/test_scheduler.sh"
}

run_skill_tests() {
  . "$TESTS_DIR/test_skill.sh"
}

run_e2e_tests() {
  . "$TESTS_DIR/test_e2e.sh"
}

case "$TEST_GROUP" in
  state)
    run_state_tests
    ;;
  execution)
    run_execution_tests
    ;;
  liveness)
    run_liveness_tests
    ;;
  scheduler)
    run_scheduler_tests
    ;;
  skill)
    run_skill_tests
    ;;
  e2e)
    run_e2e_tests
    ;;
  all)
    run_state_tests
    run_execution_tests
    run_liveness_tests
    run_scheduler_tests
    run_skill_tests
    run_e2e_tests
    ;;
  *)
    printf 'unknown test group: %s\n' "$TEST_GROUP" >&2
    exit 2
    ;;
esac

printf 'all %s tests passed\n' "$TEST_GROUP"
