# Harness hooks

Harness hooks are scripts that an AI coding harness runs at fixed points, such as after the agent edits a file. They enforce a rule every time, instead of relying on the model to remember it. This directory mirrors `~/.claude/hooks/`.

Looking for Git hooks? Those run inside Git for anyone who commits, and they live in [`git-hooks/`](../git-hooks/).

## Catalog

| Hook | Event | What it does |
|---|---|---|
| [`validate-mermaid`](validate-mermaid/) | `PostToolUse` on `Write` and `Edit` | Parses each Mermaid diagram in an edited Markdown file and returns syntax errors to the agent so it can fix them |

The CopyDesk writing-style hook that used to live here now ships with [CopyDesk](https://github.com/carlosboeing/copydesk).

## Install a hook in Claude Code

1. Copy the script into place and make it executable. `scripts/sync-toolkit.sh --harness` does this for you, or copy it by hand:

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

- **One directory per hook.** Put the script at `hooks/<name>/<name>.sh` with a README covering its purpose, requirements, settings fragment and failure behavior.
- **Fail open.** If a required tool is missing or the payload cannot be parsed, exit `0`. A hook that blocks every write because its validator is missing does more harm than no hook.
- **Exit fast when there is nothing to check.** A `PostToolUse` hook on `Write|Edit` runs on every file the agent touches, so skip irrelevant files within milliseconds.
- **Write errors for the model.** On `PostToolUse`, exit code `2` sends stderr back to the model, which then fixes the problem. Phrase the message as an instruction the model can act on.

## Other harnesses

Hook support differs between harnesses, so a hook written for Claude Code does not always carry over.

| Harness | Hook mechanism | Can a hook block the agent? |
|---|---|---|
| Claude Code | Shell commands registered in `settings.json` | Yes, including after a tool runs (`PostToolUse`) |
| OpenCode | JavaScript plugin modules in `~/.config/opencode/plugins/` | Yes, before a tool runs, by throwing an error |
| Kimi Code | `[[hooks]]` entries in `~/.kimi-code/config.toml` | Only on `PreToolUse`, `Stop` and `UserPromptSubmit`. No hook can rewrite tool input. |
| Grok Build TUI | Hooks in `~/.grok/hooks/` or `~/.grok/config.toml` | On `PreToolUse` and `Stop`. `PostToolUse` results are ignored. |

### OpenCode

OpenCode has no shell hooks. The Mermaid validator ships as a plugin module, `hooks/validate-mermaid/opencode-validate-mermaid.ts`. `scripts/sync-toolkit.sh --harness` copies it to `~/.config/opencode/plugins/validate-mermaid.ts`, where OpenCode loads it without a config entry. The plugin runs before each write and throws to stop a write that contains a broken diagram. One module serves both OpenCode plugin APIs: 2.x reads its `id` and `setup`, and 1.x (1.18.29 and newer) calls its `server()`. The [validator's README](validate-mermaid/README.md) has the version matrix.

### Kimi Code

Kimi Code's `PostToolUse` event can only observe, so a validator that reports after a write, like `validate-mermaid`, cannot feed errors back there.

### Grok Build TUI

Two separate settings matter on Grok.

1. **Grok's own hooks are enabled.** Register them in `~/.grok/hooks/*.json` or under `[hooks]` in `~/.grok/config.toml`. `PreToolUse` can deny or rewrite a tool call, and `Stop` can block and send a reason back to the model. The hook payload uses camelCase keys, such as `toolInput` instead of `tool_input`. Grok maps some Claude tool names to its own, for example `Bash` to `run_terminal_command` and `Edit`, `Write` and `MultiEdit` to `search_replace`. Check the live tool names before relying on a mapping. Grok's file-creation tool is `write`, which is not in the published mapping table.
2. **Grok does not load Claude hooks.** With `[compat.claude] hooks = false`, Grok ignores `~/.claude/settings.json` and plugin `hooks.json` files. Claude hook scripts would also fail open on Grok, because they expect snake_case keys.

Grok ignores the output and exit code of `PostToolUse` hooks, so the model never sees their result. A check that must reach the model belongs in `Stop`, or in `PreToolUse` if it can run before the tool does.

When you bring your own hook to Grok:

| Hook type | Approach |
|---|---|
| Your own `PreToolUse` or `Stop` hook | Keep one script and register it under `~/.grok/hooks/`. If it expects Claude's snake_case payload, add a small input adapter rather than rewriting the logic. |
| Your own hook that runs on `PostToolUse` | Do not port it to Grok's `PostToolUse`. Move the check to `Stop`, or run the validator manually. |
| Hooks bundled in third-party Claude plugins | Leave Claude hook loading off, and do not copy the plugin's hook files into `~/.grok/`. |
