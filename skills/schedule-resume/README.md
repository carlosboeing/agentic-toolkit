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

- On macOS: `launchd` (built in) with a logged-in GUI session — the scheduler runs jobs as user LaunchAgents in the GUI domain, which is what keeps the login keychain readable for the resumed harness. On Linux: a working `cron` with a per-user `crontab` (cronie/vixie-cron). The helper is macOS-tested this pass.
- `jq` installed.
- On macOS, `caffeinate` and `lockf` (both built in). `caffeinate -i` prevents idle sleep only while an attempt is running; on other platforms the idle guard is simply skipped.
- Each target CLI installed and authenticated: `claude`, `agy`, or `codex`. For Claude targets on macOS, create checks that the `Claude Code-credentials` keychain item is readable and warns if not.
- The computer powered on with the user logged in at trigger time. Sleep can delay a trigger (launchd coalesces missed calendar firings and runs them on wake; cron drops them).
- **Protected paths (conditional):** jobs under `~/Projects`, `~/.local`, and similar need no grant. If a job's project directory, prompt, or state root lives under a TCC-protected folder (Documents, Desktop, Downloads, iCloud Drive), the helper warns at create time: on macOS the background agent may be denied access, and on Linux-style cron setups the cron daemon may need a Full Disk Access-equivalent grant (on macOS cron that was `/usr/sbin/cron` under System Settings > Privacy & Security).

## Layout and installation

The bundle contains `SKILL.md`, this README, `scripts/resume-job.sh`, its `scripts/lib/` modules, and static/shell tests under `tests/`. Keep the directory together and keep the helper executable.

Install it like any other skill in this repo — see the [skills catalog README](../README.md#install-any-skill-in-this-directory). [`sync-skills.sh`](../sync-skills.sh) symlinks the whole `schedule-resume/` directory (scripts, libs, tests) into each installed harness at once; the helper's executable bit travels with the repo file, so no `chmod` step is needed. To consume just this one skill instead, copy its whole directory into your harness's skills directory.

## State and scheduling

Each job owns `~/.local/state/resume-job/<job-id>/`, including immutable manifest and prompt data, mutable status, a combined scheduler log at `cron.log`, and per-attempt logs at `attempts/<N>/stdout.log` and `attempts/<N>/stderr.log`. These files are created with private owner-only permissions.

Each job is scheduled by one per-job scheduler entry that runs the job's `run.sh` wrapper. The backend is chosen by OS at create time:

- **macOS — launchd**: a user LaunchAgent at `~/Library/LaunchAgents/com.carlos.resume-job.<job-id>.plist` with a calendar trigger for the first attempt and a 60-second poll interval. Running in the GUI domain is what lets a resumed `claude` read its login-keychain credentials — cron's security session cannot, which is why cron is not used on macOS.
- **Linux — cron**: a single crontab line:

```text
* * * * * '~/.local/state/resume-job/<job-id>/run.sh' # schedule-resume:<job-id>
```

Either way the entry polls every minute; the `next_attempt_at` due-gate in the helper decides when an attempt actually runs, so early polls are harmless no-ops and the first-attempt latency is about a minute. Because `--first-attempt-at` is enforced by the due-gate (not by calendar fields), it must be a UTC ISO timestamp with `:00` seconds.

Scheduler edits are safe by construction: crontab edits are serialized by a lock, touch only lines carrying the `# schedule-resume:<job-id>` marker, and preserve all your other cron lines byte-for-byte; launchd agents are per-job plists that never touch anything else.

**Scheduler cleanup.** On Linux/cron a job removes its own crontab line the moment it reaches a terminal state (completed, failed, or cancelled). On macOS a launchd child must not boot out its own agent, so a terminal job's agent stays loaded but inert until the next interactive schedule-resume command (`create`, `cancel`, `cleanup`, or `doctor`) prunes it — until then it fires a cheap no-op poll each minute. Deleting the state folder is a separate, manual step: `cleanup RETENTION_DAYS` removes terminal state older than the retention window (`0..36500` days), keeping the attempt logs available for inspection until you ask.

**Ghost prevention.** A leftover entry cannot launch anything — the helper's `run` is a pure due-gate over `status.json`, so a poke at a terminal or missing job is a no-op. On top of that, every `create`/`cancel`/`cleanup`/`doctor` reconciles the scheduler (dropping any entry whose job directory is gone or whose job is terminal).

### Migrating between backends

`doctor` detects leftovers from the other backend — stray `# schedule-resume:` crontab lines on a launchd system, or leftover LaunchAgents on a cron system — and prints the removal command. To boot out old LaunchAgents manually:

```sh
for p in "$HOME"/Library/LaunchAgents/com.carlos.resume-job.*.plist; do
  [ -e "$p" ] || continue
  launchctl bootout "gui/$(id -u)/$(basename "$p" .plist)" 2>/dev/null
  rm -f "$p"
done
```

Existing job state under `~/.local/state/resume-job/` is backend-agnostic; re-schedule an in-flight job with a fresh `create`.

## Liveness guard (Claude only)

Before a Claude job resumes, the helper reads Claude Code's own per-session registry (`~/.claude/sessions/<pid>.json`) to see whether the target session is still live, and classifies it:

- **active** — the session is open and the assistant is working. The job **defers**: no attempt is spent, no quota is used, `next_attempt_at` is re-armed one retry interval out, and the job stays `scheduled`. Each deferral bumps `defer_count`.
- **idle** — the session is open but parked at the prompt. The job resumes in place, appending to the one transcript.
- **absent** — no live session process. The job resumes in place, exactly as before.

This stops a scheduled resume from spawning a second agent on a session someone is actively using — two agents on one session interleave and corrupt the shared transcript. A deferring job never reads as stalled or failed: `status` reports `deferred_session_active` with `defer_count` and `last_deferred_at`, and `list` marks it as holding on an active target session. The job resumes on its own the first poll after the session goes idle or closes.

Detection is Claude-only. Agy and Codex expose no equivalent session registry, so their resumes proceed ungated, exactly as before. Every read fails safe: a missing sessions directory, an unparseable file, or a dead PID all resolve to "resume," never a hang. `SCHEDULE_RESUME_CLAUDE_SESSIONS_DIR` overrides the registry location and exists only for the tests.

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

The helper copies the prompt without changing its bytes, resolves the selected harness executable to an absolute path at creation, and only installs the scheduler entry during creation. On macOS, create also preflights the environment: it fails if the launchd GUI domain is unreachable (no GUI login) and warns if a Claude target has no readable keychain credential. Its fixed retry policy retries quota/availability/transient classifications; authentication, missing session, permission, and other failures are terminal.

`--completion-policy` accepts two values. `sentinel-output` (the skill's default) only completes the job once the resumed session prints the exact token `SCHEDULE_RESUME_TASK_COMPLETE` alone on its own line as its last output; any other zero exit reschedules another attempt instead of finishing early. `session-exits-zero` completes the job on any successful exit and suits narrow one-shot commands where a clean exit really does mean the work is done.

Manual management:

```sh
scripts/resume-job.sh list
scripts/resume-job.sh status JOB_ID
scripts/resume-job.sh cancel JOB_ID
scripts/resume-job.sh cleanup RETENTION_DAYS
scripts/resume-job.sh doctor
```

Do not edit manifests, state, crontab lines, or LaunchAgent plists manually. Use the helper so locking, the scheduler lifecycle, status, and retention rules remain consistent.
