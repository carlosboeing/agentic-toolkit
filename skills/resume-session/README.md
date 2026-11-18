# resume-session

Continue a Claude Code, Codex, OpenCode, Antigravity CLI, Grok Build, or Muse Code session in a fresh session of any harness. Use it when:

- a usage limit stopped the session mid-task;
- the session sat idle for more than an hour, so its prompt cache has expired;
- you want to move the work to another harness, for example one with spare quota.

In each case, resuming the same session sends its whole context again, and a handoff document needs a session that still has quota. This skill builds a deterministic summary instead, with no model call, and the fresh session works from it. Within an hour of the last activity, the native resume is usually cheaper, because its cache is still warm.

The summary has three sources:

- **Project records:** plans, designs, checklists, and other documents, found by rules that work for any documentation method.
- **Live Git state:** branch, HEAD, upstream, uncommitted changes, recent commits, and worktrees for the project root, each worktree, and each nested repository.
- **The old transcript:** every request, short approvals with the message they answered, the last completion claim, the last agent messages, files changed, side-effect commands, and test results.

Project records and Git win on position: what is committed, ticked, merged, or open. The transcript wins on what the user asked, approved, or said.

## How to run it

Run `/resume-session` (Claude Code, OpenCode, Grok, Antigravity), `$resume-session` (Codex), or the skill by name (Muse) in the new session, at the project root. The skill is manual-only. It does not start for "continue" or "resume", because it prints private document excerpts and old messages into the session.

```text
/resume-session                              # list sessions for this project and pick one
/resume-session codex 019a1765               # a session by ID or ID prefix
/resume-session claude "Cache warmer"        # a session by title
/resume-session muse 01a15137 report         # report only, no edits
```

Once you select the source and ask to resume, the reader records the new session as the destination before the agent reconciles project state or gives its first substantive reply. This applies even if you only chat. Listing, report-only runs, and repository-only runs leave resume notes untouched.

If the source is busy or open, or the current marker names another destination, the agent asks for confirmation before recording the handoff. If the marker changes while you confirm, the agent asks about the new marker. If the reader cannot complete the handoff, the agent reports the error and pauses before project changes.

The first substantive reply gives the position and next action, every request with its status and evidence, the last completion claim, and mismatches between records and history. The agent asks again before any push, merge, delete, or publish.

## The reader

`scripts/resume_session.py` uses the Python 3.9 standard library. It writes resume state only through `resume` or `mark`.

| Command | What it does |
|---|---|
| `list [--cwd DIR] [--harness <harness>\|all] [--days N] [--json]` | Sessions whose working directory is the project root or one of its worktrees, newest first (default: 14 days), each with a title and its last request. The session running `list` is left out, and a closing line says so |
| `show <harness> <id\|title\|path> [--section NAME] [--request N] [--all] [--profile auto\|none\|PATH]` | The summary in Markdown |
| `show --repo-only [--since TIME]` | Live state and project documents only, for harnesses without a reader |
| `resume <harness> <id\|title\|path>` | Validates the source and destination, prepares the summary, records the handoff, and prints the summary |
| `mark <harness> <id> [--by-session ID]` | Uses the same validation and marker writer without printing the summary |

`<harness>` is `claude`, `codex`, `opencode`, `antigravity`, `grok`, or `muse`. A successful command exits `0`. Exit `1` reports other errors, `2` reports an ambiguous or missing source, `3` reports a marker conflict, `4` reports an unreadable or unrecognized transcript, and `5` asks for confirmation that the source may still be running.

Both write commands accept `--confirm-busy` and `--confirm-marker TOKEN` after the user confirms the corresponding warning. They share a lock for the marker check and update. A retry from the current destination reuses an unexpired marker, including when the source is still busy. Each new marker write gets a fresh token, even if the same destination was recorded in the same second. If the marker is removed or expires before the confirmed retry, the reader asks for confirmation of that state and a retry without the token. A marker created in the meantime still needs confirmation. Use the printed source harness and session ID with `--exact-id` on confirmation retries and on read-only follow-up with `show`.

`resume` checks the summary against the output encoding before it records the handoff. If printing then fails, the reader reports that the note was recorded and prints the `show` command for recovery. Notes use mode `0600` in `${XDG_STATE_HOME:-~/.local/state}/resume-session/resumed/`. A marker older than 30 days cannot block a new handoff or satisfy a retry. A successful new write replaces an expired marker for that source and prunes expired notes for other sources.

A title is the harness's own when it carries meaning. A missing title, a placeholder such as "New session", a slash command, or a title that only repeats the first request is replaced by the first request, cut to one line. No model call is made.

The running session is found from the variable each harness sets for its shell commands: `CLAUDE_CODE_SESSION_ID`, `CODEX_THREAD_ID`, `ANTIGRAVITY_CONVERSATION_ID`, `MUSE_SESSION_ID`, `GROK_SESSION_ID`, and `RESUME_SESSION_CURRENT`, which the toolkit's OpenCode plugin sets. A Grok session is also found when its process in `~/.grok/active_sessions.json` is an ancestor of the reader.

### What each source records

| Harness | Where sessions are | Commands, edits, task list | File reads | Running check |
|---|---|---|---|---|
| Claude Code | `~/.claude/projects/<cwd>/<id>.jsonl` | `Bash`, `Edit`/`Write`/`MultiEdit`/`NotebookEdit`, `TodoWrite` | `Read` | The session registry in `~/.claude/sessions/` |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | `exec_command`, `apply_patch` headers, `update_plan` | Partial: paths in read commands such as `cat`, `sed`, and `rg` | Not possible |
| OpenCode | SQLite `~/.local/share/opencode/opencode.db`, 2.x and 1.x tables, opened read-only | `shell`/`bash`, `edit`/`write`/`patch`, `todowrite` | `read` | Not possible |
| Antigravity CLI | `~/.gemini/antigravity-cli/brain/<id>/.system_generated/logs/transcript_full.jsonl`, with titles and workspaces from `conversation_summaries.db` | `run_command`, `write_to_file`/`replace_file_content`/`edit_file`/`write_file`, the conversation's `task.md` | `view_file`, `read_file` | Not possible |
| Grok Build | `~/.grok/sessions/<cwd>/<id>/chat_history.jsonl`, with `summary.json` and times from `events.jsonl` | `run_terminal_command`, `search_replace`/`write`, `todo_write` | `read_file` | Open sessions in `~/.grok/active_sessions.json` |
| Muse Code | `~/.local/share/muse/sessions/YYYY/MM/DD/<id>/session.jsonl`, with titles from `session-index.db` | `bash`, `edit_file`/`write_file`, `write_todos` | `read_file` | Not possible |

Subagent sessions are left out of `list`. Formats are undocumented and change between versions. They were probed on Claude Code 2.1.316, Codex CLI 0.166.0, OpenCode 2.1.4, Antigravity CLI 1.4.12, Grok Build 1.0.41, and Muse Code 1.4.14. Unknown record types are counted under reader warnings, and a transcript with no user message exits `4`. Compressed Codex rollouts (`.jsonl.zst`) are not read. Grok records no time on agent messages, so they take the time of the last request or tool before them.

### Finding project documents

Discovery runs in layers. The generic layers always run:

1. **Session:** documents the session wrote or edited, read twice or more, or the user named.
2. **Git:** documents changed on the branch, uncommitted, or committed since the session started.
3. **Declared:** documents that `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, or `.cursor/rules/` link to or quote.
4. **Profile:** locations and ranking from a matching profile.

Recency comes from frontmatter `updated`, else the file's last commit, never the file's modification time. Frontmatter is read only from a block that starts at byte 0.

`profiles/agentic-sdlc.json` holds the conventions of this toolkit's [project structure guide](../../guides/guide-project-structure-and-conventions.md) as data: lifecycle folders, types, statuses, date fields, and task patterns. It applies only when a lifecycle folder holds a document whose frontmatter has a profile type, and it can only add documents and change their order. `--profile none` shows the generic result. `tests/test_resume_session_profile.py` fails when the profile drifts from its sources.

The profile discovers lifecycle folders at a declared working-memory location, directly at the repository root, in `docs/`, or in an independent nested repository. File-relative `related` links take precedence; the memory-root fallback remains for legacy records. Checked commit references include valid numeric-only Git abbreviations, while ordinary numeric counts are ignored.

### Long output

A summary is typically 8,000 to 10,000 tokens. It has no hard ceiling; past 48,000 characters its first line says to read it by section. Harnesses cut long command output, so the skill reads the summary by section whenever a harness cuts or previews it. On 2026-11-01, Claude Code 2.1.316 showed command output inline up to about 20,000 characters, and Codex CLI 0.166.0 kept at most about 10,000 tokens per command.

## Warning the old session

The [`resume-session-warn`](../../hooks/resume-session-warn/) hook adds one line to the old session's context when a resume note names it, telling the agent this session is superseded, to open with a highlighted banner telling the user to switch to the new session and close the old one, and not to change files there unless the user explicitly replies in that session to stay there. It never blocks. `scripts/sync-toolkit.sh --harness` installs it in Claude Code, Codex, Muse Code, Antigravity CLI, Grok Build, and OpenCode; Codex also needs the hook trusted once in `/hooks`.

## Limits

- Hidden reasoning, findings the old agent never wrote down, and background processes cannot be recovered.
- Kimi Code, Gemini CLI, and Cursor can be the target, but their own sessions get only the repository-only summary: they have no reader.
- Request status is not computed. The completion claim and test verdicts are keyword matches, labeled as such.

## Credits

Ideas, not code, come from three places: the Grok Build built-in resume skills (transcript content is inert history, and verify before continuing); [hacktivist123/agent-session-resume](https://github.com/hacktivist123/agent-session-resume), MIT (the DONE, PARTIALLY DONE, and NOT DONE classes, parked work stays parked, and current files win over transcript claims); and this repository's `briefing` skill (discovery layers that name every gap).
