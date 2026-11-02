# Harness hooks

Harness hooks are scripts that an AI coding harness runs at fixed points, such as after the agent edits a file. They enforce a rule every time, instead of relying on the model to remember it. This directory mirrors `~/.claude/hooks/`.

Looking for Git hooks? Those run inside Git for anyone who commits, and they live in [`git-hooks/`](../git-hooks/).

## Catalog

| Hook | Event | What it does |
|---|---|---|
| [`validate-mermaid`](validate-mermaid/) | `PostToolUse` on `Write` and `Edit` | Parses each Mermaid diagram in an edited Markdown file and returns syntax errors to the agent so it can fix them |
| [`validate-frontmatter`](validate-frontmatter/) | `PostToolUse` on `Write` and `Edit`, an OpenCode plugin | Checks that local paths in YAML frontmatter `related`, `supersedes` and `superseded_by` fields resolve relative to the file's directory |
| [`resume-session-warn`](resume-session-warn/) | `UserPromptSubmit` (Claude Code, Codex, Muse Code), `PreInvocation` (Antigravity CLI), `PreToolUse` (Grok Build), an OpenCode plugin | Adds one line to a session's context when [`resume-session`](../skills/resume-session/) has resumed it elsewhere, asking the agent to confirm before changing files; never blocks |

The CopyDesk writing-style hook that used to live here now ships with [CopyDesk](https://github.com/carlosboeing/copydesk).

## Install a hook in Claude Code

`scripts/sync-toolkit.sh --harness` does both steps below for every hook in this directory, and registers the toolkit's hooks in the other harnesses it finds as each hook's README describes. By hand:

1. Copy the script into place and make it executable:

   ```bash
   hook=validate-mermaid
   mkdir -p ~/.claude/hooks
   curl -fsSL -o ~/.claude/hooks/$hook.sh \
     https://raw.githubusercontent.com/carlosboeing/agentic-toolkit/main/hooks/$hook/$hook.sh
   chmod +x ~/.claude/hooks/$hook.sh
   ```

2. Add the settings fragment from the hook's README to the `hooks` section of `~/.claude/settings.json`.
3. Run `/hooks` or start a new session so Claude Code reloads its settings.

## Writing a hook

Before you write a hook, port one to another harness, or rely on an existing one in a new way:

1. **Read the harness's rows** in the [harness hooks reference](../reference/reference-harness-hooks.md), including the date checked and the open questions.
2. **Re-check the source** when the row is older than about 60 days, when the installed version has a new major or minor release, or when the row is marked unchecked.
3. **Probe the behavior you depend on** on the installed version, such as whether a blocked prompt or added context actually reaches the agent. Documentation and observed behavior sometimes disagree.
4. **Keep one core script.** Add a small input adapter and output adapter per harness for key style, session ID field and output format, rather than a copy per harness.
5. **Write findings back** to the reference, with the date, the installed version and the source, and resolve or add an open question.

The rules for this repository's hooks:

- **One directory per hook.** Put the script at `hooks/<name>/<name>.sh` with a README covering its purpose, requirements, settings fragment and failure behavior.
- **Fail open.** If a required tool is missing or the payload cannot be parsed, exit `0`. A hook that blocks every write because its validator is missing does more harm than no hook.
- **Exit fast when there is nothing to check.** A `PostToolUse` hook on `Write|Edit` runs on every file the agent touches, so skip irrelevant files within milliseconds.
- **Write errors for the model.** On `PostToolUse`, exit code `2` sends stderr back to the model, which then fixes the problem. Phrase the message as an instruction the model can act on.

## Other harnesses

Hook support differs between harnesses, so a hook written for Claude Code does not always carry over. The [harness hooks reference](../reference/reference-harness-hooks.md) records, for nine harnesses, where hooks are configured, which events can block, add context or rewrite a tool call, and which event does a common job on each. The sections below cover how this repository's hooks are installed on harnesses other than Claude Code.

### OpenCode

OpenCode has no shell hooks. The Mermaid validator ships as a plugin module, `hooks/validate-mermaid/opencode-validate-mermaid.ts`. `scripts/sync-toolkit.sh --harness` copies it to `~/.config/opencode/plugins/validate-mermaid.ts`, where OpenCode loads it without a config entry. The plugin runs before each write and throws to stop a write that contains a broken diagram. One module serves both OpenCode plugin APIs: 2.x reads its `id` and `setup`, and 1.x (1.18.29 and newer) calls its `server()`. The [validator's README](validate-mermaid/README.md) has the version matrix.

### Kimi Code

Kimi Code's `PostToolUse` event can only observe, so a validator that reports after a write, like `validate-mermaid`, cannot feed errors back there.

### Grok Build TUI

Two separate settings matter on Grok.

1. **Grok's own hooks are enabled.** Register them in `~/.grok/hooks/*.json` or under `[hooks]` in `~/.grok/config.toml`. This repository recorded on 2026-08-17 that `PreToolUse` can deny or rewrite a tool call and that `Stop` can block and send a reason back to the model; Grok's current documentation names `PreToolUse` as the only blocking event, so probe before relying on either (see the reference's open questions). The hook payload uses camelCase keys, such as `toolInput` instead of `tool_input`. Grok maps some Claude tool names to its own, for example `Bash` to `run_terminal_command` and `Edit`, `Write` and `MultiEdit` to `search_replace`. Check the live tool names before relying on a mapping. Grok's file-creation tool is `write`, which is not in the published mapping table.
2. **Grok does not load Claude hooks.** With `[compat.claude] hooks = false`, Grok ignores `~/.claude/settings.json` and plugin `hooks.json` files. Claude hook scripts would also fail open on Grok, because they expect snake_case keys.

Grok ignores the output and exit code of `PostToolUse` hooks, so the model never sees their result. A check that must reach the model belongs in `Stop`, or in `PreToolUse` if it can run before the tool does.

When you bring your own hook to Grok:

| Hook type | Approach |
|---|---|
| Your own `PreToolUse` or `Stop` hook | Keep one script and register it under `~/.grok/hooks/`. If it expects Claude's snake_case payload, add a small input adapter rather than rewriting the logic. |
| Your own hook that runs on `PostToolUse` | Do not port it to Grok's `PostToolUse`. Move the check to `Stop`, or run the validator manually. |
| Hooks bundled in third-party Claude plugins | Leave Claude hook loading off, and do not copy the plugin's hook files into `~/.grok/`. |
