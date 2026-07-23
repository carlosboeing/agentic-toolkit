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

- A working `cron` with a per-user `crontab` (macOS ships this; Linux via cronie/vixie-cron). The helper is macOS-tested this pass.
- `jq` installed.
- On macOS, `caffeinate` and `lockf` (both built in). `caffeinate -i` prevents idle sleep only while an attempt is running; on other platforms the idle guard is simply skipped.
- Each target CLI installed and authenticated: `claude`, `agy`, or `codex`.
- The computer powered on with the user logged in at trigger time. Sleep can delay a trigger.
- **macOS Full Disk Access (conditional):** cron fires jobs without Full Disk Access for normal paths. It only needs FDA when a job's project directory, prompt, or state root lives under a TCC-protected folder (Documents, Desktop, Downloads, iCloud Drive). The helper prints a warning at create time in exactly that case; grant `/usr/sbin/cron` Full Disk Access under System Settings > Privacy & Security if so. Jobs under `~/Projects`, `~/.local`, and similar need no grant.

## Layout and installation

The bundle contains `SKILL.md`, this README, `scripts/resume-job.sh`, its `scripts/lib/` modules, and static/shell tests under `tests/`. Keep the directory together and keep the helper executable.

Install it like any other skill in this repo — see the [skills catalog README](../README.md#install-any-skill-in-this-directory). [`sync-skills.sh`](../sync-skills.sh) symlinks the whole `schedule-resume/` directory (scripts, libs, tests) into each installed harness at once; the helper's executable bit travels with the repo file, so no `chmod` step is needed. To consume just this one skill instead, copy its whole directory into your harness's skills directory.

## State and scheduling

Each job owns `~/.local/state/resume-job/<job-id>/`, including immutable manifest and prompt data, mutable status, a combined scheduler log at `cron.log`, and per-attempt logs at `attempts/<N>/stdout.log` and `attempts/<N>/stderr.log`. These files are created with private owner-only permissions.

Each job is scheduled by a single crontab line that runs the job's `run.sh` wrapper:

```text
* * * * * '~/.local/state/resume-job/<job-id>/run.sh' # schedule-resume:<job-id>
```

The line polls every minute; the `next_attempt_at` due-gate in the helper decides when an attempt actually runs, so early polls are harmless no-ops and the first-attempt latency is about a minute. Because `--first-attempt-at` is enforced by the due-gate (not by cron's calendar fields), it must be a UTC ISO timestamp with `:00` seconds.

Crontab edits are safe by construction: every edit is serialized by a lock, touches only lines carrying the `# schedule-resume:<job-id>` marker, and preserves all your other cron lines byte-for-byte.

**Automatic scheduler cleanup.** A job removes its own crontab line the moment it reaches a terminal state (completed, failed, or cancelled), so only actively scheduled or retrying jobs ever have a line. A finished job leaves just an inert state folder — nothing polling. Deleting that folder is a separate, manual step: `cleanup RETENTION_DAYS` removes terminal state older than the retention window (`0..36500` days), keeping the attempt logs available for inspection until you ask. Skipping cleanup only leaves small folders on disk; no cron lines, nothing firing.

**Ghost prevention.** A leftover line cannot launch anything — the helper's `run` is a pure due-gate over `status.json`, so a poke at a terminal or missing job is a no-op. On top of that, every `create`/`cancel`/`cleanup` reconciles the crontab (dropping any marker line whose job directory is gone), and `doctor` prunes orphans on demand.

### Migrating from the old launchd backend

Earlier versions installed one `~/Library/LaunchAgents/com.carlos.resume-job.<job-id>.plist` per job. This version uses cron instead. `doctor` detects any leftover LaunchAgents and prints the removal command; to boot them out manually:

```sh
for p in "$HOME"/Library/LaunchAgents/com.carlos.resume-job.*.plist; do
  [ -e "$p" ] || continue
  launchctl bootout "gui/$(id -u)/$(basename "$p" .plist)" 2>/dev/null
  rm -f "$p"
done
```

Existing job state under `~/.local/state/resume-job/` is compatible; re-schedule an in-flight job with a fresh `create`.

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
  --completion-policy sentinel-output \
  --permissions-mode full-auto
```

The helper copies the prompt without changing its bytes, resolves the selected harness executable to an absolute path at creation, and only installs the cron entry during creation. Its fixed retry policy retries quota/availability/transient classifications; authentication, missing session, permission, and other failures are terminal.

`--completion-policy` accepts two values. `sentinel-output` (the skill's default) only completes the job once the resumed session prints the exact token `SCHEDULE_RESUME_TASK_COMPLETE` alone on its own line as its last output; any other zero exit reschedules another attempt instead of finishing early. `session-exits-zero` completes the job on any successful exit and suits narrow one-shot commands where a clean exit really does mean the work is done.

Manual management:

```sh
scripts/resume-job.sh list
scripts/resume-job.sh status JOB_ID
scripts/resume-job.sh cancel JOB_ID
scripts/resume-job.sh cleanup RETENTION_DAYS
scripts/resume-job.sh doctor
```

Do not edit manifests, state, or crontab lines manually. Use the helper so locking, the cron lifecycle, status, and retention rules remain consistent.
