# Schedule Resume

`/schedule-resume` schedules an unattended continuation of an existing Claude Code, Agy, or Codex coding session. It can start at an explicit time or a known usage-reset time, then retry only quota or service-availability failures until the resumed session exits successfully.

## Examples

```text
/schedule-resume
/schedule-resume resume Claude session 8b2f... from this Codex project when usage resets at 23:00, retry every 15 minutes
/schedule-resume resume my Agy conversation at 2026-07-23 06:30 Australia/Brisbane
/schedule-resume retry every 10 minutes until the session exits zero
/schedule-resume list scheduled jobs
/schedule-resume show status for job-20260722T130000Z-1234
/schedule-resume cancel job-20260722T130000Z-1234
/schedule-resume clean up terminal jobs older than 30 days
```

The skill confirms all consequential values before creation and states: `This will not start another run now.` Read-only list and status requests do not need confirmation. Cancellation requires a job ID unless there is exactly one active job. Cleanup always requires confirmation and a retention period.

## Prerequisites

- macOS with the built-in `launchd`, `launchctl`, `plutil`, `caffeinate`, and `lockf` tools.
- `jq` installed.
- Each target CLI installed and authenticated: `claude`, `agy`, or `codex`.
- The Mac powered on with the user logged in at trigger time. Sleep can delay a trigger; `caffeinate -i` prevents idle sleep only while an attempt is running.

## Layout and installation

The bundle contains `SKILL.md`, this README, `scripts/resume-job.sh`, its `scripts/lib/` modules, and static/shell tests under `tests/`. Keep the directory together and keep the helper executable.

Install it like any other skill in this repo — see the [skills catalog README](../README.md#install-any-skill-in-this-directory). [`sync-skills.sh`](../sync-skills.sh) symlinks the whole `schedule-resume/` directory (scripts, libs, tests) into each installed harness at once; the helper's executable bit travels with the repo file, so no `chmod` step is needed. To consume just this one skill instead, copy its whole directory into your harness's skills directory.

## State and scheduling

Each job owns `~/.local/state/resume-job/<job-id>/`, including immutable manifest and prompt data, mutable status, scheduler logs at `launchd.stdout.log` and `launchd.stderr.log`, and per-attempt logs at `attempts/<N>/stdout.log` and `attempts/<N>/stderr.log`. These files are created with private owner-only permissions. Its scheduler definition is `~/Library/LaunchAgents/com.carlos.resume-job.<job-id>.plist`.

The LaunchAgent combines a calendar trigger for the first attempt with an interval trigger for retries. Because launchd calendar triggers are minute-granular, `--first-attempt-at` must be a UTC ISO timestamp with `:00` seconds. Due-time gating makes early triggers no-ops. Completed, failed, and cancelled terminal states are no-ops and persist until explicit cleanup. Cancellation unloads the scheduler and records terminal state. Cleanup removes eligible terminal jobs and their plists after a retention period from `0..36500` days.

## Native resume commands

The helper uses prompt stdin and these current native forms:

| Target | Invocation | Yolo flag |
|---|---|---|
| Claude | `claude --resume SESSION --print` | `--dangerously-skip-permissions` |
| Agy | `agy --conversation SESSION --print` | `--dangerously-skip-permissions` |
| Codex | `codex exec resume SESSION -` | `--dangerously-bypass-approvals-and-sandbox` |

These permissions are intentionally fixed as `full-auto` for unattended work and are dangerous. The skill must warn and obtain confirmation before creation.

## Helper operations

The create contract is:

```text
scripts/resume-job.sh create \
  --target-harness claude|agy|codex \
  --session-id ID \
  --project-dir ABSOLUTE_DIR \
  --prompt-file FILE \
  --schedule-type calendar|reset \
  --first-attempt-at UTC_ISO_WITH_00_SECONDS \
  --retry-interval-seconds N \
  --retry-policy until-completed \
  --completion-policy session-exits-zero \
  --permissions-mode full-auto
```

The helper copies the prompt without changing its bytes, resolves the selected harness executable to an absolute path at creation, and only bootstraps the scheduler during creation. Its fixed retry policy retries quota/availability classifications; authentication, missing session, permission, and other failures are terminal.

Manual management:

```sh
scripts/resume-job.sh list
scripts/resume-job.sh status JOB_ID
scripts/resume-job.sh cancel JOB_ID
scripts/resume-job.sh cleanup RETENTION_DAYS
```

Do not edit manifests, state, or plists manually. Use the helper so locking, launchd lifecycle, status, and retention rules remain consistent.
