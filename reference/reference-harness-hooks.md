---
title: Harness hooks
type: reference
scope: [hooks, harnesses, cross-harness]
last_reviewed: 2026-11-01
authors:
  - "Carlos Boeing"
  - "claude-opus-5-5 (claude-code)"
related:
  - reference/reference-harness-capability-map.md
  - hooks/README.md
  - guides/guide-harness-plugin-parity.md
---

# Harness hooks

What a hook can do in each of nine AI coding harnesses: where hooks are configured, which events can block, add context the agent sees, or rewrite a tool call, and what the payload looks like. It is the single source for these facts in this repository; other documents link here instead of restating them. Use it before you write, port, or rely on a hook, together with the process in [Writing a hook](../hooks/README.md#writing-a-hook).

Facts were checked against each product's documentation on 2026-10-31 unless a row says otherwise. The version column is the version installed when the row was checked, not a version the documentation names. Hook systems change between releases, so check the date and the source before relying on a row.

## Where hooks live and what they receive

| Harness (version checked) | User hook configuration | Project hooks and trust | Input keys and session ID | Output | Source |
|---|---|---|---|---|---|
| Claude Code (2.1.314) | `~/.claude/settings.json`; also plugin `hooks/hooks.json`, skill and subagent frontmatter, managed policy settings | `.claude/settings.json` and `.claude/settings.local.json` | snake_case; `session_id`, `transcript_path`, `cwd` | Exit code; plain stdout on some events; JSON with camelCase `hookSpecificOutput` | [Hooks reference](https://code.claude.com/docs/en/hooks) |
| Codex CLI (0.166.0) | `~/.codex/hooks.json` or `~/.codex/config.toml`; plugin hooks; managed `requirements.toml` | `<repo>/.codex/hooks.json` or `config.toml`, loaded only when the project layer is trusted. Every non-managed hook must be trusted in `/hooks`, by hash, and is skipped again after it changes | snake_case; `session_id` (subagent hooks get the parent's), `transcript_path` (nullable) | Plain stdout on some events; JSON with camelCase `hookSpecificOutput` | [Codex hooks](https://learn.chatgpt.com/docs/hooks) |
| Gemini CLI (0.53.0) | `~/.gemini/settings.json` under `hooks`; system `/etc/gemini-cli/settings.json`; extensions | `.gemini/settings.json`. Project hooks are fingerprinted, and a changed hook is treated as untrusted and warned about before it runs | snake_case; `session_id` | JSON only on stdout; logs go to stderr | [Hooks overview](https://geminicli.com/docs/hooks/), [reference](https://geminicli.com/docs/hooks/reference/) |
| Antigravity (agy 1.4.12) | `~/.gemini/config/hooks.json`; a CLI plugin's `hooks.json`. Not `~/.gemini/antigravity-cli/settings.json`. Hook names sit at the top: `{"<name>": {"PreInvocation": [handler]}}` (probed 2026-11-01) | `.agents/hooks.json`. The hooks page does not state a trust rule | camelCase; `conversationId` | JSON on stdout | [Antigravity hooks](https://antigravity.google/docs/hooks) |
| Kimi Code (2.1.1) | `[[hooks]]` in `~/.kimi-code/config.toml`; local plugins | None by design | snake_case; `session_id` | Exit `2` blocks with the stderr text as the reason; returned text goes to context on some events | [Kimi Code hooks](https://moonshotai.github.io/kimi-code/en/customization/hooks) |
| Grok Build (1.0.41) | `~/.grok/hooks/*.json`; this repository also recorded `[hooks]` in `~/.grok/config.toml` on 2026-08-17 | `<project>/.grok/hooks/*.json`, after trust through `/hooks-trust` or `--trust`, stored in `~/.grok/trusted_folders.toml`. The documentation says Claude Code and Cursor hook files are also read; `[compat.claude] hooks = false` in `~/.grok/config.toml` turns Claude hooks off | camelCase; `hookEventName`, `sessionId`, `cwd`, `workspaceRoot`; environment variable `GROK_SESSION_ID` | `PreToolUse` writes a JSON decision; stdout of passive events is ignored | [Grok Build hooks](https://docs.x.ai/build/features/hooks) |
| OpenCode (2.1.4) | JavaScript or TypeScript plugin modules in `~/.config/opencode/plugins/`, or packages in the `plugins` config array (`plugin` on 1.x) | Not checked | Plugin API objects; `sessionID` | Code: a plugin throws to refuse, or edits the output object | [OpenCode plugins](https://opencode.ai/docs/plugins/); installed `@opencode-ai/plugin` 1.17.3 types |
| Cursor (cursor-agent 2026.10.22) | `~/.cursor/hooks.json`; enterprise files such as `/Library/Application Support/Cursor/hooks.json` on macOS; team dashboard; plugins | `<project>/.cursor/hooks.json` | snake_case; `conversation_id` (`session_id` on `sessionStart`, equal to it) | JSON; exit `2` blocks | [Cursor hooks](https://cursor.com/docs/hooks) |
| Muse Code (1.4.14) | Plugins: a bundle with `.muse-plugin/plugin.json` and `capabilities.hooks` entries (`id`, `event`, `command` as an argument list relative to the bundle, `timeoutMs`), installed with `muse plugins install <dir>` and approved with `muse plugins approve <id>` (probed 2026-11-01) | `muse plugins install --scope project` | snake_case; `hook_event_name`, `session_id`, `turn_id`, `cwd`, `prompt`; environment variables `MUSE_SESSION_ID`, `MUSE_PLUGIN_ROOT` | Plain stdout on `UserPromptSubmit` reaches the model; JSON `additionalContext` did not | `muse plugins --help`; local probe |

## What a hook can do

| Harness | Can block | Adds context the agent sees | Rewrites a tool call | Observes only |
|---|---|---|---|---|
| Claude Code | Exit `2` on `PreToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStop`, `PostToolBatch`, `PreCompact` and others. JSON `decision` on `PermissionRequest`; on `PostToolUse` the reason reaches the agent but the tool has already run | Plain stdout on `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, `PostModelSwitch`. `additionalContext` on those and on `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Stop`, `SubagentStart`, `SubagentStop`. Word it as a statement: the reference warns that instruction-style text can trigger prompt-injection defenses | `PreToolUse` `updatedInput`; `PermissionRequest` `updatedInput`. `PostToolUse` can replace the output with `updatedToolOutput` | `Notification`, `SessionStart`, `SessionEnd`, `StopFailure`, `PermissionDenied`, `CwdChanged`, `FileChanged`, and others |
| Codex CLI | `PreToolUse`, `PermissionRequest`, `UserPromptSubmit`, `PreCompact`. `Stop` and `SubagentStop` with `decision: "block"` continue the turn. `PostToolUse` feedback replaces the result, but the command has run | `additionalContext` or plain stdout on `SessionStart`, `SubagentStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse` | `PreToolUse` `updatedInput` with `permissionDecision: "allow"` | `SessionEnd`, `SubagentStart`, `Interrupt` |
| Gemini CLI | `decision: "deny"` or exit `2` on `BeforeTool`, `AfterTool`, `BeforeModel`, `AfterModel`. `BeforeAgent` `deny` drops the prompt; `continue: false` blocks and keeps it. `AfterAgent` `deny` forces a retry | `hookSpecificOutput.additionalContext` on `BeforeAgent` (that turn only), `AfterTool` (appended to the result), `SessionStart` | `BeforeTool` `hookSpecificOutput.tool_input`; `BeforeModel` and `AfterModel` can rewrite the model request and response | `BeforeToolSelection`, `SessionStart`, `SessionEnd`, `Notification`, `PreCompress` |
| Antigravity | `PreToolUse` `decision` `deny`, or an approval gate with `ask`; `Stop` `decision: "continue"`; `PostInvocation` `terminationBehavior: "terminate"` | `injectSteps` with `systemMessage`, `userMessage`, `ephemeralMessage` or `toolCall` on `SessionStart`, `PreInvocation` (before each model call), `PostInvocation`; the `Stop` reason when it continues | `PreToolUse` `overwrite`, shallow-merged into the tool arguments | `PostToolUse`, which returns `{}` |
| Kimi Code | `UserPromptSubmit`, `PreToolUse`, `Stop`, by exit `2` | `UserPromptSubmit` returned text "is appended to context" (see [open questions](#open-questions)); `PreToolUse` exit-`0` stdout "may be appended"; a blocking `Stop` message | No | `PostToolUse`, `PostToolUseFailure`, `SessionStart`, `PermissionRequest` and all other events. `PreCompact` output is ignored completely |
| Grok Build | `PreToolUse`, "the only blocking event" according to the documentation (see [open questions](#open-questions)) | `hookSpecificOutput.additionalContext` from `PreToolUse` and `PostToolUse`, delivered with the tool result, according to the hook reference bundled in the 1.0.41 binary. That reference says a `UserPromptSubmit` block reason "is never added to the model's context" | Not documented (see [open questions](#open-questions)) | Passive events, whose stdout is ignored. `PostToolUse` results never reach the model |
| OpenCode | Before a tool runs, by throwing: `ctx.tool.hook("execute.before", ...)` on 2.x, `tool.execute.before` on 1.x | 1.x: `chat.message` (editable message parts) and `experimental.chat.system.transform` (adds system lines, receives `sessionID`). 2.x: `ctx.session.hook("context", ...)` before each model request, with `sessionID`, `system` and `messages` to edit; `prompt` edits the stored prompt draft ([server plugins](https://opencode.ai/v2/docs/build/plugins/server), probed on 2.1.4) | Yes, through a plugin (recorded 2026-09-23) | `tool.execute.after`, which cannot block on either API |
| Cursor | `preToolUse`, `subagentStart`, `beforeShellExecution`, `beforeMCPExecution`, `beforeReadFile`, `beforeSubmitPrompt`; any command hook exiting `2` | `additional_context` on `postToolUse`, `postToolUseFailure`, `sessionStart` (initial system context only). `followup_message` on `stop` and `subagentStop` is sent as the next message. `agent_message` on a denial. `beforeSubmitPrompt` adds no context | `preToolUse` `updated_input` | `afterFileEdit`, `afterShellExecution`, `sessionEnd`, `preCompact`, and others |
| Muse Code | Unchecked | Plain stdout on `UserPromptSubmit` (probed 2026-11-01) | Unchecked | Unchecked |

## Common jobs and the event that does each

Most hooks in this repository do one of three jobs. The event that does the job differs per harness, and on some harnesses the job has to move to another event.

| Job | Claude Code | Codex CLI | Gemini CLI | Antigravity | Kimi Code | Grok Build | OpenCode | Cursor |
|---|---|---|---|---|---|---|---|---|
| Check a file after the agent writes it, and send errors back | `PostToolUse`, exit `2` | `PostToolUse` feedback | `AfterTool` `additionalContext` | Not after the write: check in `PreToolUse` | Not after the write: check in `Stop` | Not after the write: check in `Stop` or `PreToolUse` | Not after the write: check before it and throw | `postToolUse` `additional_context` |
| Refuse or change a tool call before it runs | `PreToolUse` | `PreToolUse` | `BeforeTool` | `PreToolUse` | `PreToolUse`, refuse only | `PreToolUse` | `execute.before` | `preToolUse` |
| Add a fact to the agent's context when the user sends a prompt | `UserPromptSubmit` stdout | `UserPromptSubmit` stdout | `BeforeAgent` | `PreInvocation` | `UserPromptSubmit`, to be probed | Not available; the closest is `PreToolUse` `additionalContext`, delivered with the first tool result | Plugin `context` hook (2.x) or `experimental.chat.system.transform` (1.x) | Not available; `sessionStart` only at session start |

The [`validate-mermaid`](../hooks/validate-mermaid/) hook is the first row: a `PostToolUse` script on Claude Code and a plugin that checks before the write on OpenCode.

## Failure behavior

Most harnesses let an action through when a hook fails, so a broken hook does not stop the agent; this repository's hooks also fail open by convention ([Writing a hook](../hooks/README.md#writing-a-hook)).

- **Kimi Code:** exit `0` allows, exit `2` blocks, and any other exit, timeout or crash allows. The first failure in a session shows a warning once.
- **Grok Build:** timeouts, crashes and malformed output are fail-open; only an explicit `deny` blocks.
- **Gemini CLI:** stdout must be the final JSON only. Plain text on stdout breaks the parse, so write logs to stderr.
- **Claude Code:** exit codes other than `0` and `2` are non-blocking errors.

## Probed on the installed version

| Harness | Finding | Checked |
|---|---|---|
| Claude Code 2.1.316 | `claude -p --resume <id>` passes the original `session_id` to `UserPromptSubmit`, equal to the transcript file name, and appends to the same transcript. An interactive `claude --resume` was not tested | 2026-11-01, logging hook passed with `--settings` |
| Codex CLI 0.166.0 | A `UserPromptSubmit` hook's `session_id` equals the rollout ID in the transcript file name and `CODEX_THREAD_ID`, and its plain stdout reaches the model | 2026-11-01, one `codex exec --dangerously-bypass-hook-trust` run in a throwaway repository |
| Antigravity CLI 1.4.12 | A `PreInvocation` hook runs before each model call with `conversationId`, `invocationNum`, `transcriptPath` and `workspacePaths`; `{"injectSteps": [{"ephemeralMessage": ...}]}` reaches the model from `~/.gemini/config/hooks.json` or a project `.agents/hooks.json`. From an installed plugin's `hooks.json` the hook runs but its `ephemeralMessage` or `systemMessage` never arrives. A file with event names at the top fails to parse and loads no hooks. `ANTIGRAVITY_CONVERSATION_ID` is set for shell commands | 2026-11-01, `agy -p` with `--log-file` |
| Muse Code 1.4.14 | A plugin `UserPromptSubmit` hook gets `session_id`, equal to `MUSE_SESSION_ID` and the session folder name; plain stdout reaches the model, JSON `additionalContext` did not. Approval is stored in `~/.config/muse/settings.json` | 2026-11-01, `muse exec` |
| OpenCode 2.1.4 | `ctx.session.hook("context")` gets `sessionID`, equal to the `session_v2` row; a text part added to the latest user message reaches the model. `ctx.tool.hook("execute.before")` gets `sessionID`; `ctx.shell.hook("create.before")` does not, but runs after it for the same command and can set `env`. `OPENCODE_SESSION_ID` in a shell does not match the stored session ID. `opencode run` takes its directory from `PWD` | 2026-11-01, project plugin and `opencode run --standalone` |
| Grok Build 1.0.41 | A `UserPromptSubmit` hook in `~/.grok/hooks/*.json` gets `hookEventName` `user_prompt_submit`, `sessionId`, `cwd`, `workspaceRoot`; `GROK_SESSION_ID` and `GROK_WORKSPACE_ROOT` are set. Delivery to the model was not tested: the account returned 402 | 2026-11-01, `grok -p` |
| Codex CLI 0.166.0 | `codex exec` skips an untrusted hook in a project's `.codex/hooks.json`. `codex exec --dangerously-bypass-hook-trust` runs enabled hooks without stored trust for one run, including untrusted user hooks | 2026-11-01, run and `codex exec --help` |

## Open questions

Each needs a probe on the installed version before a hook depends on it.

| Question | Conflicting evidence |
|---|---|
| Does Grok's `Stop` hook block, and can its `PreToolUse` hook rewrite a tool call? | This repository recorded both on 2026-08-17 ([Grok Build TUI hooks](../hooks/README.md#grok-build-tui)); the [Grok documentation](https://docs.x.ai/build/features/hooks) calls `PreToolUse` "the only blocking event" and documents only allow and deny |
| Does Grok's `PreToolUse` `additionalContext` reach the model? | The bundled hook reference says so; the 2026-11-01 probe could not reach the model |
| Does Kimi's `UserPromptSubmit` output reach the model? | The [hooks page](https://moonshotai.github.io/kimi-code/en/customization/hooks) says returned text "is appended to context"; a [help page](https://www.kimi.com/en/help/kimi-code/cli-hooks) says hook output is shown to the user and saved to history but not sent to the model |
