# resume-session-warn

A hook that tells an agent its session was resumed somewhere else. When [`resume-session`](../../skills/resume-session/) continues a session in a fresh one, it writes a resume note. If someone later types into the old session, this hook adds one line to that session's context, for example:

> This session was resumed in Codex at 2026-10-31 10:47 +10:00 for the project at /home/dev/app. Work done here can conflict with that session. Ask the user to confirm before changing any file in this session.

The hook never blocks. A prompt in the old session always goes through, and the agent asks before it changes files.

## Why it exists

A session left open in a tab is the case it covers. After a usage limit resets, the user may type into the old tab while the work has moved to a new session. Two agents then edit the same files without knowing about each other. `UserPromptSubmit` runs on that next prompt; `SessionStart` would not, because the session never restarts.

Claude Code's hook reference advises factual wording, because instruction-style text can trigger its prompt-injection defenses. A factual line alone was not enough: on 2026-11-01, Claude Code 2.1.316 with Sonnet and with Opus mentioned the resume only after making the edit it was asked for. The old session never loads the `resume-session` skill, so nothing else tells it to wait. With the last sentence added, both models stopped, wrote nothing, and asked, and neither treated the line as an injection.

## Requirements

- Claude Code or Codex. Other harnesses have no transcript reader yet, so no note can name their sessions.
- `jq` on `PATH`.
- Notes in `${XDG_STATE_HOME:-$HOME/.local/state}/resume-session/resumed/`, written by `resume_session.py mark`.

## Install in Claude Code

`scripts/sync-toolkit.sh --harness` copies the script to `~/.claude/hooks/resume-session-warn.sh`. It does not register it. Add this to the `hooks` section of `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh ~/.claude/hooks/resume-session-warn.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

## Install in Codex

Add this to `~/.codex/hooks.json`, pointing at the same copy:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh ~/.claude/hooks/resume-session-warn.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Codex runs a non-managed hook only after you trust it in `/hooks`, and again after the file changes, because trust is stored per hash. Until then the hook does nothing, and `resume-session`'s `list` and `show` still report the resume.

## Session IDs

The hook matches the `session_id` in its input against the note's file name, `<harness>-<session-id>.json`.

| Harness | What was checked | Result |
|---|---|---|
| Claude Code 2.1.316 | `claude -p`, then `claude -p --resume <id>`, with a logging hook, 2026-11-01 | Both prompts report the original `session_id`, equal to the transcript file name. An interactive `claude --resume` was not tested |
| Codex CLI 0.166.0 | Logging hook in a project `.codex/hooks.json`, 2026-11-01 | Not verified: Codex skipped the untrusted hook. Whether the hook's `session_id` equals the rollout ID in the transcript file name is unknown |

When the IDs differ, the hook prints nothing. The cost is a missing warning, not a blocked prompt.

## Failure behavior

Every path exits `0`.

| Case | Effect |
|---|---|
| No note for this session | Prints nothing |
| `jq` missing, input not JSON, no `session_id` | Prints nothing |
| A `session_id` with characters other than letters, digits, and `-` | Prints nothing; the ID is never used in a path |
| The Codex hook not yet trusted | Codex skips the hook; no warning |

Without a note the hook takes a median of 5.6 ms (20 runs, 2026-11-01).
