# resume-session-warn

A hook for Claude Code, Codex, Muse Code, Antigravity CLI, Grok Build, and OpenCode that tells an agent its session was resumed somewhere else. When [`resume-session`](../../skills/resume-session/) continues a session in a fresh one, it writes a resume note. If someone later types into the old session, this hook adds one line to that session's context, for example:

> This session was resumed in Codex at 2026-10-31 10:47 +10:00 for the project at /home/dev/app. Work done here can conflict with that session. Ask the user to confirm before changing any file in this session.

The hook never blocks. A prompt in the old session always goes through, and the agent asks before it changes files.

## Why it exists

A session left open in a tab is the case it covers. After a usage limit resets, the user may type into the old tab while the work has moved to a new session. Two agents then edit the same files without knowing about each other. `UserPromptSubmit` runs on that next prompt; `SessionStart` would not, because the session never restarts.

Claude Code's hook reference advises factual wording, because instruction-style text can trigger its prompt-injection defenses. A factual line alone was not enough: on 2026-11-01, Claude Code 2.1.316 with Sonnet and with Opus mentioned the resume only after making the edit it was asked for. The old session never loads the `resume-session` skill, so nothing else tells it to wait. With the last sentence added, both models stopped, wrote nothing, and asked, and neither treated the line as an injection.

## Requirements

- `jq` on `PATH`, for the shell script. The OpenCode plugin needs nothing extra.
- Notes in `${XDG_STATE_HOME:-$HOME/.local/state}/resume-session/resumed/`, written by `resume_session.py mark`.

## Install

`scripts/sync-toolkit.sh --harness` installs and registers the hook in every harness it finds, and `--dry-run` shows what it would change. It copies the script to `~/.claude/hooks/resume-session-warn.sh`, then [`scripts/register_hooks.py`](../../scripts/register_hooks.py) adds the entries below. An entry that already names the script is left alone, and each settings file is copied to `<file>.agentic-toolkit.bak` once, before its first change. A file that does not parse is reported and not changed.

| Harness | What sync writes | Event and output | Manual step |
|---|---|---|---|
| Claude Code | `UserPromptSubmit` in `~/.claude/settings.json` | Plain text, added to the context | None |
| Codex CLI | `UserPromptSubmit` in `~/.codex/hooks.json` | Plain text, added to the context | Trust it once in `/hooks`. Codex skips an untrusted hook and stores trust per hash, so trust again after the script changes. Sync reports the step until Codex records trust |
| Muse Code | A local plugin built from [`muse-plugin/`](muse-plugin/), installed with `muse plugins install` and approved with `muse plugins approve` | `UserPromptSubmit`, plain text | None |
| Antigravity CLI | A `resume-session-warn` entry in `~/.gemini/config/hooks.json`, run with the `antigravity` argument | `PreInvocation`, before each model call; prints `{"injectSteps": [{"ephemeralMessage": ...}]}` | None, unless the file holds entries in a layout Antigravity cannot parse; see below |
| Grok Build | `~/.grok/hooks/resume-session-warn.json`, run with the `grok` argument | `PreToolUse` on every tool; prints `hookSpecificOutput.additionalContext` | None |
| OpenCode | [`opencode-resume-session-warn.ts`](opencode-resume-session-warn.ts) copied to `~/.config/opencode/plugins/resume-session-warn.ts` | The 2.x `context` hook adds the line to the latest user turn of each request; on 1.x, `experimental.chat.system.transform` | None |

The OpenCode plugin also sets `RESUME_SESSION_CURRENT=opencode:<session-id>` for shell commands. OpenCode's own `OPENCODE_SESSION_ID` does not match the stored session ID, so this is how `resume-session list` leaves the running OpenCode session out.

### Where each harness puts the line, and why

Each harness was probed on 2026-11-01 with a hook that printed a test word, then with the shipped hook and a test note, asking the agent to create a file:

| Harness | Line reached the model | Agent asked before writing |
|---|---|---|
| Claude Code 2.1.316 | Yes | Yes, with Sonnet and Opus |
| Codex CLI 0.166.0 | Yes | Not run with the shipped hook |
| Muse Code 1.4.14 | Yes, as plain text; JSON `additionalContext` did not arrive | Yes |
| Antigravity CLI 1.4.12 | Yes, from `~/.gemini/config/hooks.json` or a project `.agents/hooks.json`. From a plugin's `hooks.json` the hook ran but its output never arrived | Yes |
| OpenCode 2.1.4 | Yes | As a system-prompt line, three models wrote the file anyway. Next to the user turn, all three tried to ask; `opencode run` cancels questions in headless mode, so they went on |
| Grok Build 1.0.41 | Not tested: the account returned 402. Grok's bundled hook reference says `UserPromptSubmit` output never reaches the model, and that `PreToolUse` `additionalContext` arrives with the tool result | Not tested |

On Grok the line arrives with the first tool result of a turn, so an edit that is the first tool call runs before the agent sees it.

### Antigravity hooks file layout

Antigravity CLI 1.4.12 reads hook names at the top of `hooks.json`: `{"<name>": {"PreInvocation": [handler]}}`. A file with event names at the top (`{"PreInvocation": [{"matcher": ..., "hooks": [...]}]}`) fails to parse, and then no hook in it loads (`agy --log-file` shows `cannot unmarshal array into Go struct field .PreInvocation of type jsonhook.JSONHookSpec`). Sync does not rewrite another tool's entries. When it finds that layout it reports it and leaves the file alone; convert those entries to the name-first layout, then run sync again.

## Session IDs

The hook reads `session_id`, `sessionId`, or `conversationId` from its input and looks for `<harness>-<session-id>.json` among the notes, for all six harness names.

| Harness | Field | Checked on 2026-11-01 |
|---|---|---|
| Claude Code 2.1.316 | `session_id` | Equals the transcript file name, also after `claude -p --resume`. An interactive `claude --resume` was not tested |
| Codex CLI 0.166.0 | `session_id` | Equals the rollout ID in the transcript file name and `CODEX_THREAD_ID` |
| Muse Code 1.4.14 | `session_id` | Equals the session folder name and `MUSE_SESSION_ID` |
| Antigravity CLI 1.4.12 | `conversationId` | Equals the `brain/<id>` folder and `ANTIGRAVITY_CONVERSATION_ID` |
| Grok Build 1.0.41 | `sessionId` | Equals the session folder name and `GROK_SESSION_ID` |
| OpenCode 2.1.4 | `event.sessionID` in the plugin | Equals the `session_v2` row ID |

When the IDs differ, the hook prints nothing. The cost is a missing warning, not a blocked prompt.

## Failure behavior

Every path exits `0`.

| Case | Effect |
|---|---|
| No note for this session | Prints nothing |
| `jq` missing, input not JSON, no session ID | Prints nothing (`{}` with the `antigravity` argument) |
| A session ID with characters other than letters, digits, `_`, and `-` | Prints nothing; the ID is never used in a path |
| The Codex hook not yet trusted | Codex skips the hook; no warning |

Without a note the hook takes a median of 5.6 ms (20 runs, 2026-11-01).
