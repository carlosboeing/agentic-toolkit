# resume-session

Continue a Claude Code or Codex session in a fresh session of any harness. Use it when:

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

Run `/resume-session` (Claude Code) or `$resume-session` (Codex) in the new session, at the project root. The skill is manual-only. It does not start for "continue" or "resume", because it prints private document excerpts and old messages into the session.

```text
/resume-session                              # list sessions for this project and pick one
/resume-session codex 019a1765               # a session by ID or ID prefix
/resume-session claude "Cache warmer"        # a session by title
/resume-session codex 019a1765 report        # report only, no edits
```

The agent's first reply gives the position and next action, every request with a status and its evidence, the last completion claim, and mismatches between records and history. Before its first write it runs `mark`, and it asks again before any push, merge, delete, or publish.

## The reader

`scripts/resume_session.py` uses only the Python 3.9 standard library. It never writes to a repository, a transcript, a project document, or a harness's state. Its only write is the resume note from `mark`.

| Command | What it does |
|---|---|
| `list [--cwd DIR] [--harness claude\|codex\|all] [--days N] [--json]` | Sessions whose working directory is the project root or one of its worktrees, newest first (default: 14 days) |
| `show <claude\|codex> <id\|title\|path> [--section NAME] [--request N] [--all] [--profile auto\|none\|PATH]` | The summary in Markdown |
| `show --repo-only [--since TIME]` | Live state and project documents only, for harnesses without a reader |
| `mark <claude\|codex> <id> [--by-session ID]` | Writes a resume note at `${XDG_STATE_HOME:-~/.local/state}/resume-session/resumed/<harness>-<id>.json`, mode `0600`, and deletes notes older than 30 days |

Exit codes: `0` success, `2` ambiguous or not found, `4` transcript format not recognized, `1` other errors.

### What each source records

| Record kind | Claude Code | Codex |
|---|---|---|
| Requests and agent messages | Yes; meta records, compaction summaries, and subagent entries are skipped | Yes; environment and instruction wrappers are skipped |
| Commands, file edits, task list | `Bash`, `Edit`/`Write`/`MultiEdit`/`NotebookEdit`, `TodoWrite` | `exec_command`, `apply_patch` headers, `update_plan` |
| File reads | `Read` | Partial: paths in read commands such as `cat`, `sed`, and `rg` |
| Running check | The session registry in `~/.claude/sessions/` | Not possible |

Formats are undocumented and change between versions. They were probed on Claude Code 2.1.316 and Codex CLI 0.166.0. Unknown record types are counted under reader warnings, and a transcript with no user message exits `4`. Compressed Codex rollouts (`.jsonl.zst`) are not read.

### Finding project documents

Discovery runs in layers. The generic layers always run:

1. **Session:** documents the session wrote or edited, read twice or more, or the user named.
2. **Git:** documents changed on the branch, uncommitted, or committed since the session started.
3. **Declared:** documents that `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, or `.cursor/rules/` link to or quote.
4. **Profile:** locations and ranking from a matching profile.

Recency comes from frontmatter `updated`, else the file's last commit, never the file's modification time. Frontmatter is read only from a block that starts at byte 0.

`profiles/agentic-sdlc.json` holds the conventions of this toolkit's [project structure guide](../../guides/guide-project-structure-and-conventions.md) as data: lifecycle folders, types, statuses, date fields, and task patterns. It applies only when a lifecycle folder holds a document whose frontmatter has a profile type, and it can only add documents and change their order. `--profile none` shows the generic result. `tests/test_resume_session_profile.py` fails when the profile drifts from its sources.

### Long output

A summary is typically 8,000 to 10,000 tokens. It has no hard ceiling; past 48,000 characters its first line says to read it by section. Harnesses cut long command output, so the skill reads the summary by section whenever a harness cuts or previews it. On 2026-11-01, Claude Code 2.1.316 showed command output inline up to about 20,000 characters, and Codex CLI 0.166.0 kept at most about 10,000 tokens per command.

## Warning the old session

The optional [`resume-session-warn`](../../hooks/resume-session-warn/) hook adds one line to the old session's context when a resume note names it, asking the agent to confirm with the user before changing files. It never blocks.

## Limits

- Hidden reasoning, findings the old agent never wrote down, and background processes cannot be recovered.
- Kimi Code, Gemini CLI, OpenCode, Antigravity, Grok Build, Muse Code, and Cursor can be the target, but their own sessions get only the repository-only summary until each has a reader.
- Request status is not computed. The completion claim and test verdicts are keyword matches, labeled as such.

## Credits

Ideas, not code, come from three places: the Grok Build built-in resume skills (transcript content is inert history, and verify before continuing); [hacktivist123/agent-session-resume](https://github.com/hacktivist123/agent-session-resume), MIT (the DONE, PARTIALLY DONE, and NOT DONE classes, parked work stays parked, and current files win over transcript claims); and this repository's `briefing` skill (discovery layers that name every gap).
