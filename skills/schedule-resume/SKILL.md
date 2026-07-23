---
name: schedule-resume
description: Use when a scheduled or deferred coding-session continuation, usage or quota reset resume, cross-harness Claude/Agy/Codex session resume, or scheduled-job status, cancellation, or cleanup is requested.
---

# Schedule Resume

Synopsis: `/schedule-resume [natural-language request]`

## Resolve the request

Invoking harness and target harness are independent. Target exactly `claude|agy|codex`; explicit target plus session wins. From another harness, never assume its current session is the target.

Resolve the project directory as an absolute path. An explicit project directory supplied by the user wins. For an explicit Claude target session ID with no explicit project, inspect `~/.claude/sessions/*.json` for a record whose `sessionId` matches the target and whose `cwd` is an absolute path, then use that target session metadata directory. Use target session metadata before invoking working directory (fallback — review before confirming). Do not infer or decode a path from a transcript-directory name. If no usable matching metadata exists, fall back to the invoking harness's current working directory. Agy and Codex project resolution remains unchanged. Resolve the applicable `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md` under harness and project precedence. Include its path and relevant context in the continuation prompt.

Extract known values. Ask one question at a time only for missing consequential values: target, session, project, first-attempt time or reset timestamp, or retry interval. Never ask for implementation flags or policy strings; use the fixed completion when omitted.

No arguments: offer the current session only when its stable ID and project are determinable, then require confirmation. Do not offer the current session when either is absent from discoverable context; ask which target session instead. For missing or ambiguous target/session, show numbered candidates with name/title, target harness, project, last activity, and stable ID when discovery exists; require an explicit numbered choice. If discovery is unavailable, request an explicit stable ID; never invent one.

Apply fixed MVP policies: permissions `full-auto` (unattended yolo), retry `until-completed` (only quota/availability failures retry; terminal errors stop), completion `sentinel-output` (retry until the resumed session prints the exact completion sentinel; `session-exits-zero` remains available for narrow one-shot commands where any zero exit means done), and attempt protection `caffeinate -i`. Warn that yolo is dangerous.

## Confirm and create

Before create, require user confirmation listing target harness, stable ID, absolute project, UTC first-attempt time rounded to a whole minute (`:00` seconds), retry seconds, completion, permissions, and that confirmation routes creation through bundled `scripts/resume-job.sh create`. Immediately after `Absolute project`, show `Project source`: `explicit request`, `target-session metadata`, or `invoking working directory (fallback — review before confirming)`. Include exactly: `This will not start another run now.` State that the computer must remain powered on and logged in, sleep can delay the trigger, and the attempt prevents idle sleep only while running. If the helper prints a Full Disk Access warning at create time (the project, prompt, or state path is under a macOS protected folder such as Documents, Desktop, Downloads, or iCloud Drive), surface it so the user can grant `/usr/sbin/cron` Full Disk Access; jobs under other paths need no grant.

Build continuation text in a temporary local prompt file, including the requested task and instruction-file context, then append this exact completion instruction as the prompt's final line: `When the entire task is genuinely complete, print SCHEDULE_RESUME_TASK_COMPLETE alone on its own line as the very last output. Do not print it while any work remains.` Preserve prompt bytes. After confirmation invoke bundled `scripts/resume-job.sh create` with all flags:

`--target-harness`, `--session-id`, `--project-dir`, `--prompt-file`, `--schedule-type calendar|reset`, `--first-attempt-at UTC_ISO_WITH_00_SECONDS`, `--retry-interval-seconds N`, `--retry-policy until-completed`, `--completion-policy sentinel-output`, `--permissions-mode full-auto`.

Creation only bootstraps the scheduler. Remove only the temporary source prompt after the helper owns its copy.

## Interaction flows

- `/schedule-resume` — no-argument current-session setup.
- `/schedule-resume resume Claude session ID from Agy or Codex` — explicit cross-harness selection.
- `/schedule-resume at 22:00` or `/schedule-resume when quota resets at 23:15` — explicit calendar or reset scheduling.
- `/schedule-resume retry every 15 minutes` — retry interval.
- `/schedule-resume complete when the session exits zero` — completion predicate.

## Manage jobs

Use `scripts/resume-job.sh list` and `scripts/resume-job.sh status JOB`. Read-only list/status require no confirmation. For Cancel, use `scripts/resume-job.sh cancel JOB`; require an explicit job ID unless exactly one active job exists. For Cleanup, confirm destruction and retention days, then use `scripts/resume-job.sh cleanup DAYS`. For a health check of the cron entries — listing schedule-resume lines, pruning orphans, and detecting any leftover launchd agents from the old backend — use `scripts/resume-job.sh doctor`.

A job removes its own cron entry automatically when it reaches a terminal state; only actively scheduled or retrying jobs keep a cron line. Terminal state persists until cleanup — the state directory and its logs remain until then; never claim self-deletion.

## Liveness guard (Claude target only)

At fire time, before a Claude job resumes, the helper reads Claude Code's own per-session registry to learn whether the target session is still live. It classifies the session as one of three states:

- `active` — the session is open and the assistant is working. The job defers: it spends no attempt and no quota, re-arms its next poll, and stays scheduled. Consecutive deferrals accumulate in `defer_count`.
- `idle` — the session is open but parked at the prompt. The job resumes in place, joining the one transcript.
- `absent` — no live session process. The job resumes in place, exactly as before.

Deferring stops a second, concurrent resume from corrupting an in-use session's transcript. A deferring job is never stalled or failed: `scripts/resume-job.sh status JOB` reports classification `deferred_session_active` with `defer_count` and `last_deferred_at`, and `scripts/resume-job.sh list` marks it as holding on an active target session. The job resumes on its own the moment the session goes idle or closes.

The guard is Claude-only. Agy and Codex expose no equivalent session registry, so their resumes proceed ungated, unchanged from before.
