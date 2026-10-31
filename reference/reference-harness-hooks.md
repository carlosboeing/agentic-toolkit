---
title: Harness hooks
type: reference
scope: [hooks, harnesses, cross-harness]
last_reviewed: 2026-10-31
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
| Antigravity (agy 1.4.12) | `~/.gemini/config/hooks.json`; a CLI plugin's `hooks.json`. Not `~/.gemini/antigravity-cli/settings.json` | `.agents/hooks.json`. The hooks page does not state a trust rule | camelCase; `conversationId` | JSON on stdout | [Antigravity hooks](https://antigravity.google/docs/hooks) |
| Kimi Code (2.1.1) | `[[hooks]]` in `~/.kimi-code/config.toml`; local plugins | None by design | snake_case; `session_id` | Exit `2` blocks with the stderr text as the reason; returned text goes to context on some events | [Kimi Code hooks](https://moonshotai.github.io/kimi-code/en/customization/hooks) |
| Grok Build (1.0.41) | `~/.grok/hooks/*.json`; this repository also recorded `[hooks]` in `~/.grok/config.toml` on 2026-08-17 | `<project>/.grok/hooks/*.json`, after trust through `/hooks-trust` or `--trust`, stored in `~/.grok/trusted_folders.toml`. The documentation says Claude Code and Cursor hook files are also read; `[compat.claude] hooks = false` in `~/.grok/config.toml` turns Claude hooks off | camelCase; `hookEventName`, `sessionId`, `cwd`, `workspaceRoot`; environment variable `GROK_SESSION_ID` | `PreToolUse` writes a JSON decision; stdout of passive events is ignored | [Grok Build hooks](https://docs.x.ai/build/features/hooks) |
| OpenCode (2.1.4) | JavaScript or TypeScript plugin modules in `~/.config/opencode/plugins/`, or packages in the `plugins` config array (`plugin` on 1.x) | Not checked | Plugin API objects; `sessionID` | Code: a plugin throws to refuse, or edits the output object | [OpenCode plugins](https://opencode.ai/docs/plugins/); installed `@opencode-ai/plugin` 1.17.3 types |
| Cursor (cursor-agent 2026.10.22) | `~/.cursor/hooks.json`; enterprise files such as `/Library/Application Support/Cursor/hooks.json` on macOS; team dashboard; plugins | `<project>/.cursor/hooks.json` | snake_case; `conversation_id` (`session_id` on `sessionStart`, equal to it) | JSON; exit `2` blocks | [Cursor hooks](https://cursor.com/docs/hooks) |
| Muse Code (1.4.14) | Claude-format hooks in `$XDG_CONFIG_HOME/muse/settings.json`, according to a third-party integration. Another report says the documented `.muse/hooks.json` is ignored and hooks ship inside native plugins | Unchecked | Claude-shaped, according to the same integration | Unchecked | [kit PR 194](https://github.com/kenn-io/kit/pull/194), [ACP report](https://agenticcontrolplane.com/blog/muse-code-acp-integration) |

## What a hook can do

| Harness | Can block | Adds context the agent sees | Rewrites a tool call | Observes only |
|---|---|---|---|---|
| Claude Code | Exit `2` on `PreToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStop`, `PostToolBatch`, `PreCompact` and others. JSON `decision` on `PermissionRequest`; on `PostToolUse` the reason reaches the agent but the tool has already run | Plain stdout on `UserPromptSubmit`, `UserPromptExpansion`, `SessionStart`, `PostModelSwitch`. `additionalContext` on those and on `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `Stop`, `SubagentStart`, `SubagentStop`. Word it as a statement: the reference warns that instruction-style text can trigger prompt-injection defenses | `PreToolUse` `updatedInput`; `PermissionRequest` `updatedInput`. `PostToolUse` can replace the output with `updatedToolOutput` | `Notification`, `SessionStart`, `SessionEnd`, `StopFailure`, `PermissionDenied`, `CwdChanged`, `FileChanged`, and others |
| Codex CLI | `PreToolUse`, `PermissionRequest`, `UserPromptSubmit`, `PreCompact`. `Stop` and `SubagentStop` with `decision: "block"` continue the turn. `PostToolUse` feedback replaces the result, but the command has run | `additionalContext` or plain stdout on `SessionStart`, `SubagentStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse` | `PreToolUse` `updatedInput` with `permissionDecision: "allow"` | `SessionEnd`, `SubagentStart`, `Interrupt` |
| Gemini CLI | `decision: "deny"` or exit `2` on `BeforeTool`, `AfterTool`, `BeforeModel`, `AfterModel`. `BeforeAgent` `deny` drops the prompt; `continue: false` blocks and keeps it. `AfterAgent` `deny` forces a retry | `hookSpecificOutput.additionalContext` on `BeforeAgent` (that turn only), `AfterTool` (appended to the result), `SessionStart` | `BeforeTool` `hookSpecificOutput.tool_input`; `BeforeModel` and `AfterModel` can rewrite the model request and response | `BeforeToolSelection`, `SessionStart`, `SessionEnd`, `Notification`, `PreCompress` |
| Antigravity | `PreToolUse` `decision` `deny`, or an approval gate with `ask`; `Stop` `decision: "continue"`; `PostInvocation` `terminationBehavior: "terminate"` | `injectSteps` with `systemMessage`, `userMessage`, `ephemeralMessage` or `toolCall` on `SessionStart`, `PreInvocation` (before each model call), `PostInvocation`; the `Stop` reason when it continues | `PreToolUse` `overwrite`, shallow-merged into the tool arguments | `PostToolUse`, which returns `{}` |
| Kimi Code | `UserPromptSubmit`, `PreToolUse`, `Stop`, by exit `2` | `UserPromptSubmit` returned text "is appended to context" (see [open questions](#open-questions)); `PreToolUse` exit-`0` stdout "may be appended"; a blocking `Stop` message | No | `PostToolUse`, `PostToolUseFailure`, `SessionStart`, `PermissionRequest` and all other events. `PreCompact` output is ignored completely |
| Grok Build | `PreToolUse`, "the only blocking event" according to the documentation (see [open questions](#open-questions)) | Not documented | Not documented (see [open questions](#open-questions)) | Passive events, whose stdout is ignored. `PostToolUse` results never reach the model |
| OpenCode | Before a tool runs, by throwing: `ctx.tool.hook("execute.before", ...)` on 2.x, `tool.execute.before` on 1.x | On the 1.x plugin API: `chat.message` (editable message parts) and `experimental.chat.system.transform` (adds system lines, receives `sessionID`). The 2.x equivalents are not checked | Yes, through a plugin (recorded 2026-09-23) | `tool.execute.after`, which cannot block on either API |
| Cursor | `preToolUse`, `subagentStart`, `beforeShellExecution`, `beforeMCPExecution`, `beforeReadFile`, `beforeSubmitPrompt`; any command hook exiting `2` | `additional_context` on `postToolUse`, `postToolUseFailure`, `sessionStart` (initial system context only). `followup_message` on `stop` and `subagentStop` is sent as the next message. `agent_message` on a denial. `beforeSubmitPrompt` adds no context | `preToolUse` `updated_input` | `afterFileEdit`, `afterShellExecution`, `sessionEnd`, `preCompact`, and others |
| Muse Code | Unchecked | Unchecked | Unchecked | Unchecked |

## Common jobs and the event that does each

Most hooks in this repository do one of three jobs. The event that does the job differs per harness, and on some harnesses the job has to move to another event.

| Job | Claude Code | Codex CLI | Gemini CLI | Antigravity | Kimi Code | Grok Build | OpenCode | Cursor |
|---|---|---|---|---|---|---|---|---|
| Check a file after the agent writes it, and send errors back | `PostToolUse`, exit `2` | `PostToolUse` feedback | `AfterTool` `additionalContext` | Not after the write: check in `PreToolUse` | Not after the write: check in `Stop` | Not after the write: check in `Stop` or `PreToolUse` | Not after the write: check before it and throw | `postToolUse` `additional_context` |
| Refuse or change a tool call before it runs | `PreToolUse` | `PreToolUse` | `BeforeTool` | `PreToolUse` | `PreToolUse`, refuse only | `PreToolUse` | `execute.before` | `preToolUse` |
| Add a fact to the agent's context when the user sends a prompt | `UserPromptSubmit` stdout | `UserPromptSubmit` stdout | `BeforeAgent` | `PreInvocation` | `UserPromptSubmit`, to be probed | Not documented | Plugin chat hook | Not available; `sessionStart` only at session start |

The [`validate-mermaid`](../hooks/validate-mermaid/) hook is the first row: a `PostToolUse` script on Claude Code and a plugin that checks before the write on OpenCode.

## Failure behavior

Most harnesses let an action through when a hook fails, so a broken hook does not stop the agent; this repository's hooks also fail open by convention ([Writing a hook](../hooks/README.md#writing-a-hook)).

- **Kimi Code:** exit `0` allows, exit `2` blocks, and any other exit, timeout or crash allows. The first failure in a session shows a warning once.
- **Grok Build:** timeouts, crashes and malformed output are fail-open; only an explicit `deny` blocks.
- **Gemini CLI:** stdout must be the final JSON only. Plain text on stdout breaks the parse, so write logs to stderr.
- **Claude Code:** exit codes other than `0` and `2` are non-blocking errors.

## Open questions

Each needs a probe on the installed version before a hook depends on it.

| Question | Conflicting evidence |
|---|---|
| Does Grok's `Stop` hook block, and can its `PreToolUse` hook rewrite a tool call? | This repository recorded both on 2026-08-17 ([Grok Build TUI hooks](../hooks/README.md#grok-build-tui)); the [Grok documentation](https://docs.x.ai/build/features/hooks) calls `PreToolUse` "the only blocking event" and documents only allow and deny |
| Does Kimi's `UserPromptSubmit` output reach the model? | The [hooks page](https://moonshotai.github.io/kimi-code/en/customization/hooks) says returned text "is appended to context"; a [help page](https://www.kimi.com/en/help/kimi-code/cli-hooks) says hook output is shown to the user and saved to history but not sent to the model |
| Does Grok's `UserPromptSubmit` or `SessionStart` output reach the model? | Not documented |
| What are OpenCode 2.x's equivalents of the 1.x chat hooks? | Only the 1.x plugin types were checked |
| Where does Muse Code load hooks from, and in which format? | Two third-party reports disagree |
