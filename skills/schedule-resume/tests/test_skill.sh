#!/bin/sh

SKILL_DIR=$(CDPATH='' cd -- "$TESTS_DIR/.." && pwd)
SKILL_FILE="$SKILL_DIR/SKILL.md"
README_FILE="$SKILL_DIR/README.md"
CATALOG_FILE="$SKILL_DIR/../README.md"
HELPER_FILE="$SKILL_DIR/scripts/resume-job.sh"

assert_contains() {
  file=$1
  text=$2
  message=$3
  grep -F -- "$text" "$file" >/dev/null || fail "$message (missing '$text' in '$file')"
}

assert_matches() {
  file=$1
  pattern=$2
  message=$3
  grep -E -- "$pattern" "$file" >/dev/null || fail "$message (pattern '$pattern' missing from '$file')"
}

assert_not_matches() {
  file=$1
  pattern=$2
  message=$3
  if grep -Ei -- "$pattern" "$file" >/dev/null; then
    fail "$message (unexpected pattern '$pattern' in '$file')"
  fi
}

assert_not_contains() {
  file=$1
  text=$2
  message=$3
  if grep -F -- "$text" "$file" >/dev/null; then
    fail "$message (unexpected '$text' in '$file')"
  fi
}

assert_file_exists "$SKILL_FILE" "provide agent-facing skill instructions"
assert_file_exists "$README_FILE" "provide human-facing skill documentation"
assert_file_exists "$CATALOG_FILE" "provide the skills catalog"
[ -x "$HELPER_FILE" ] || fail "bundled helper must exist and be executable"

frontmatter=$(awk 'NR == 1 && $0 == "---" { in_frontmatter = 1; next } in_frontmatter && $0 == "---" { exit } in_frontmatter { print }' "$SKILL_FILE")
expected_frontmatter='name: schedule-resume
description: Use when a scheduled or deferred coding-session continuation, usage or quota reset resume, cross-harness Claude/Agy/Codex session resume, or scheduled-job status, cancellation, or cleanup is requested.'
assert_equal "$expected_frontmatter" "$frontmatter" "frontmatter contains exactly the approved name and description"
description=$(printf '%s\n' "$frontmatter" | sed -n 's/^description: *//p')
case "$description" in
  'Use when '*) ;;
  *) fail "description must begin with 'Use when'" ;;
esac
assert_not_matches "$SKILL_FILE" '^description:.*(asks|invokes|creates|uses the helper|confirms)' "description must contain triggering conditions only"
pass "skill metadata contract"

assert_contains "$SKILL_FILE" '/schedule-resume [natural-language request]' "document the synopsis"
assert_contains "$SKILL_FILE" 'No arguments' "cover current-session setup"
assert_contains "$SKILL_FILE" 'Do not offer the current session' "withhold an undiscoverable current-session candidate"
assert_contains "$SKILL_FILE" 'Invoking harness and target harness are independent' "separate invoking and target harnesses"
assert_contains "$SKILL_FILE" 'claude|agy|codex' "allow only supported target harnesses"
assert_contains "$SKILL_FILE" 'numbered candidates' "require candidate discovery output"
assert_contains "$SKILL_FILE" 'explicit numbered choice' "require explicit candidate selection"
assert_contains "$SKILL_FILE" 'stable ID' "require stable session identity"
assert_contains "$SKILL_FILE" 'CLAUDE.md' "resolve Claude project instructions"
assert_contains "$SKILL_FILE" 'AGENTS.md' "resolve Codex project instructions"
assert_contains "$SKILL_FILE" 'GEMINI.md' "resolve Agy project instructions"
assert_contains "$SKILL_FILE" 'absolute' "resolve an absolute project directory"
assert_contains "$SKILL_FILE" 'one question at a time' "collect only one ambiguity at a time"
assert_not_contains "$SKILL_FILE" 'retry interval, or completion predicate' "use the fixed completion policy when omitted"
assert_not_matches "$SKILL_FILE" 'target defaults to (the )?(current|invoking)|use (the )?current (session|harness) as (the )?target' "do not infer target from the invoking harness"
pass "session and project resolution contract"

for policy in full-auto until-completed session-exits-zero sentinel-output 'caffeinate -i'; do
  assert_contains "$SKILL_FILE" "$policy" "encode fixed MVP policy '$policy'"
done
assert_contains "$SKILL_FILE" 'quota/availability' "limit retries to availability failures"
assert_contains "$SKILL_FILE" 'terminal errors stop' "stop retrying terminal errors"
assert_contains "$SKILL_FILE" 'yolo is dangerous' "warn about unattended permissions"
assert_contains "$SKILL_FILE" 'This will not start another run now.' "prevent immediate-run misunderstanding"
assert_contains "$SKILL_FILE" 'powered on and logged in' "state launchd availability requirement"
assert_contains "$SKILL_FILE" 'sleep can delay' "state sleep limitation"
assert_contains "$SKILL_FILE" 'idle sleep' "scope caffeinate protection"
pass "defaults and confirmation contract"

for flag in --target-harness --session-id --project-dir --prompt-file --schedule-type --first-attempt-at --retry-interval-seconds --retry-policy --completion-policy --permissions-mode; do
  assert_contains "$SKILL_FILE" "$flag" "use helper create flag '$flag'"
done
for command in create list status cancel cleanup; do
  assert_matches "$SKILL_FILE" "resume-job\\.sh ${command}([[:space:]]|\`|$)" "route '$command' through the bundled helper"
done
assert_contains "$SKILL_FILE" 'temporary' "build a local temporary continuation prompt"
assert_contains "$SKILL_FILE" 'Preserve prompt bytes' "preserve continuation prompt bytes"
assert_contains "$SKILL_FILE" 'Terminal state persists until cleanup' "retain terminal jobs"
assert_not_matches "$SKILL_FILE" 'resume-job\.sh run|launchctl[[:space:]]+(start|kickstart)' "create flow must never start a run immediately"
assert_not_matches "$SKILL_FILE" 'claude --resume|agy --conversation|codex exec resume' "route target execution through the helper"
assert_not_matches "$SKILL_FILE" 'eval|sh -c|<<-?[[:space:]]*EOF|--prompt([ =]|$)|(echo|printf).*>(.*)(prompt|continuation)|(prompt|continuation).*(echo|printf).*>' "do not recommend inline prompt shell construction"
pass "helper routing contract"

assert_contains "$SKILL_FILE" 'Cancel' "cover cancellation"
assert_contains "$SKILL_FILE" 'exactly one active job' "allow the sole safe cancel inference"
assert_contains "$SKILL_FILE" 'Cleanup' "cover cleanup"
assert_contains "$SKILL_FILE" 'retention days' "require cleanup retention"
assert_contains "$SKILL_FILE" 'Read-only list/status require no confirmation' "keep read-only management non-interactive"
pass "management interaction contract"

for dependency in macOS jq cron crontab caffeinate lockf; do
  assert_contains "$README_FILE" "$dependency" "document dependency '$dependency'"
done
for form in '--resume' '--conversation' 'exec resume' 'prompt stdin'; do
  assert_contains "$README_FILE" "$form" "document native resume form '$form'"
done
home_tilde='~'
assert_contains "$README_FILE" "${home_tilde}/.local/state/resume-job/<job-id>/" "document job state path"
assert_contains "$README_FILE" 'cron.log' "document scheduler log"
assert_contains "$README_FILE" 'attempts/<N>/stdout.log' "document per-attempt stdout log"
assert_contains "$README_FILE" 'attempts/<N>/stderr.log' "document per-attempt stderr log"
assert_contains "$README_FILE" '# schedule-resume:<job-id>' "document the crontab line marker"
assert_matches "$README_FILE" 'polls every minute|every minute' "document minute polling"
assert_contains "$README_FILE" 'doctor' "document the doctor command"
assert_contains "$README_FILE" 'Full Disk Access' "document the conditional Full Disk Access requirement"
assert_contains "$README_FILE" '0..36500' "document cleanup retention range"
assert_matches "$README_FILE" '^/schedule-resume' "use the slash command in natural-language examples"
assert_not_matches "$README_FILE" '^/(resume|schedule-session)' "do not invent alternate slash commands"
pass "human documentation contract"

assert_contains "$CATALOG_FILE" '[`schedule-resume`](schedule-resume/)' "catalog the skill"
assert_contains "$CATALOG_FILE" '/schedule-resume' "catalog the slash command"
assert_matches "$CATALOG_FILE" 'schedule-resume.*(bundled|shell helper).*(macOS|cron)|schedule-resume.*(macOS|cron).*(bundled|shell helper)' "catalog bundled helper and cron backend"
pass "catalog contract"
