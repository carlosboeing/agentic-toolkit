# hooks/

Claude Code lifecycle hooks — shell scripts wired into `settings.json` events (`PreToolUse`, `PostToolUse`, `Stop`, …) so the harness enforces behavior deterministically, instead of relying on the model remembering a convention. This directory mirrors `~/.claude/hooks/`.

**Looking for git hooks?** They are in [`git-hooks/`](../git-hooks/). These intercept the agent's tool calls; those run in git, for anyone committing, and install into a target repository rather than into `~/.claude/`.

## Install (shared pattern)

1. Copy the hook script into place and make it executable:

```bash
HOOK=validate-mermaid   # ← or whichever hook you want
mkdir -p ~/.claude/hooks
curl -fsSL -o ~/.claude/hooks/$HOOK.sh \
  https://raw.githubusercontent.com/carlosboeing/agentic-toolkit/main/hooks/$HOOK/$HOOK.sh
chmod +x ~/.claude/hooks/$HOOK.sh
```

2. Merge the hook's settings fragment (in each item's README) into `~/.claude/settings.json` under `"hooks"`, then run `/hooks` once (or restart) so the session reloads config.

## Catalog

| Hook | Event | What it does |
|---|---|---|
| [`validate-mermaid/`](validate-mermaid/) | `PostToolUse` on `Write\|Edit` | Parse-validates every Mermaid block in a modified `.md` file; blocks with actionable feedback when a block won't render. |
| `copydesk` | `PreToolUse` on `Write\|Edit` and `UserPromptSubmit` | Extracted to [`carlosboeing/copydesk`](https://github.com/carlosboeing/copydesk) on 2026-08-19. Reconstructs Markdown edits, refuses a write carrying newly written errors, and injects a 49-word precis each turn. |

## Conventions for this type

- One subdirectory per hook: `hooks/<name>/<name>.sh` + `README.md` (purpose, requirements, settings fragment, failure behavior).
- Scripts read the hook JSON payload from stdin and must **fail open** on infrastructure problems (missing tools, unparseable payload) — a hook that blocks all writes because its validator is missing is worse than no hook.
- Keep the fast path fast: bail out in milliseconds for files/events the hook doesn't care about — `PostToolUse` on `Write|Edit` fires on *every* file Claude touches.
- Exit `2` + stderr is the blocking-feedback channel on `PostToolUse`: the message is fed back to the model, which fixes the problem and retries. Write stderr for the model, not for a human log.

## Other harnesses

Kimi Code has a hooks system too (`[[hooks]]` in `~/.kimi-code/config.toml`), but its event semantics differ in two load-bearing ways: only `PreToolUse`, `Stop`, and `UserPromptSubmit` can block (its `PostToolUse` is observation-only), and no event can rewrite tool input. Blocking validators like `validate-mermaid` therefore stay Claude-only; interception hooks of the RTK command-rewriting kind are impossible on Kimi.

### OpenCode

OpenCode has no shell hooks. `validate-mermaid` ships as `hooks/validate-mermaid/opencode-validate-mermaid.ts`. `./skills/sync-skills.sh` copies it to `~/.config/opencode/plugins/validate-mermaid.ts`. The plugin hooks `tool.execute.before` and throws to stop the write. `plugins/rtk.ts` is not copied; run `rtk init -g --opencode`.

### Grok Build TUI

Two independent facts. Do not collapse them.

1. **Grok's own hook system is on.** Register hooks in `~/.grok/hooks/*.json` or `[hooks]` in `~/.grok/config.toml`. PreToolUse can deny and rewrite. Stop can block and feed a reason back to the model. Stdin is camelCase (`toolInput`, not `tool_input`). Matcher aliases map some Claude tool names (`Bash` → `run_terminal_command`, `Edit`/`Write`/`MultiEdit` → `search_replace`). Confirm live names before relying on an alias — Grok's create-file tool is `write`, and that name is not in the published alias table.
2. **Claude hook ingest is off.** `[compat.claude] hooks = false`. Grok does not load `~/.claude/settings.json` or plugin `hooks.json`. Inherited `rtk hook claude` and `validate-mermaid.sh` are not in the active list. Even if ingest came back, those scripts would fail-open: they read snake_case.

**PostToolUse is not a soft gate.** Grok ignores PostToolUse stdout and exit code. The hook may log or annotate scrollback. The model never sees the result. Claude mermaid is already after the write — exit 2 does not roll the file back; it forces the error into the model's context. On Grok that loop does not exist. Instructions cannot act on a result that never entered the prompt. A sidecar file the model is told to read is a skippable ritual, not the same mechanism.

Use Stop when the model must hear a after-the-fact check. Use PreToolUse when you can decide before the tool runs. Do not ask PostToolUse to grow a soft gate.

**Authoring rule.** One policy script. Per-harness registration. At most one stdin remapper. Do not fork a Grok-native copy of the lint or rewrite logic.

| Kind | Do this |
|---|---|
| Owned hook, PreToolUse or Stop | Keep one script. Register it under `~/.grok/hooks/` (or config.toml). If it still speaks Claude snake_case, remap stdin — do not rewrite the policy. |
| Owned hook that is a PostToolUse gate today (`validate-mermaid`) | Do not port it as Grok PostToolUse. Move the decision to Stop, or keep the manual validator. |
| Third-party Claude plugin hooks | Leave ingest off. Do not copy their hook trees into `~/.grok/`. They stay Claude-only until xAI dual-reads snake_case *and* honors `enabledPlugins: false`. |

A universal transformer is the reuse story for **casing**. It is not a reason to turn Claude ingest back on for the whole plugin set. Ingest without enablement is how `explanatory-output-style` comes back.

Do not register a shim in front of inherited Claude plugin hooks. That was the fifth-harness pass. Owned tools are the opposite: register them natively on Grok if you want them to run.

**Worked example — CopyDesk's gate.** The gate is PreToolUse on Markdown Write/Edit, so the *event* works on Grok. The linter reads `tool_name` in `{Write, Edit}` and `tool_input.file_path`. On Grok that payload is camelCase and the tools are `write` / `search_replace`. Without a remapper the hook fail-opens and never lints. Test by registering the same `gate.sh` under `~/.grok/hooks/` and dumping stdin once before changing the parser. Retry state today lives under `~/.claude/plain-english/`; a Grok session needs its own dest or it will share Claude's counter.
