---
title: Harness capability map
type: reference
last_reviewed: 2026-09-23
authors:
  - "Carlos Boeing"
  - "k3 (kimi-code)"
  - "grok-4.6 (grok)"
  - "claude-opus-5 (claude-code)"
  - "MiMo-V2.6-Pro (opencode)"
related:
  - guides/guide-harness-plugin-parity.md
  - guides/guide-ai-model-and-effort-routing.md
---

# Harness capability map

What each supported AI coding harness can do, feature by feature, as recorded when each harness was integrated with this toolkit. Product behavior changes between releases, so check the dates below and the product's own documentation before relying on a row. For installation steps, see the [new-machine setup guide](../guides/guide-new-machine-setup.md) and the [plugin parity guide](../guides/guide-harness-plugin-parity.md).

This map is the index of harness capabilities. Where a capability has its own reference, a row summarizes it and links there, and the detail file holds the dated facts and sources:

| Capability | Detail reference |
|---|---|
| Hooks: configuration, blocking, added context, rewriting tool calls, payloads | [Harness hooks](reference-harness-hooks.md), nine harnesses, checked 2026-10-31 |

## At a glance

| Capability | Claude Code | Codex | Antigravity | Kimi Code | Grok Build TUI | OpenCode |
|---|---|---|---|---|---|---|
| Global instructions | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.gemini/GEMINI.md` | `~/.agents/AGENTS.md` | `~/.claude/CLAUDE.md` through Claude compatibility | `~/.config/opencode/AGENTS.md` |
| Skills directory | `~/.claude/skills` (the hub) | `~/.agents/skills` | `~/.gemini/config/skills` | `~/.agents/skills` | The hub, through Claude compatibility | The hub and `~/.agents/skills` |
| Hooks that can block the agent ([detail](reference-harness-hooks.md)) | Yes, including after a tool runs | Yes, before a tool runs, on prompt submit and on stop | Before a tool runs, and on stop | Before a tool runs, on stop and on prompt submit | Before a tool runs; stop is disputed | Before a tool runs |
| Hooks that can rewrite a tool call ([detail](reference-harness-hooks.md)) | Yes | Yes, before a tool runs | Yes, before a tool runs | No | Disputed | Yes, through a plugin |
| Hooks that add context on each prompt ([detail](reference-harness-hooks.md)) | Yes | Yes | Yes, before each model call | Disputed | No; `PreToolUse` context arrives with the tool result | Through a plugin, on 1.x and 2.x |
| RTK mode | Automatic hook | Automatic hook (`rtk hook codex`), trusted once in `/hooks` | Automatic hook (`rtk hook antigravity`) | `rtk` prefix in instructions | `rtk` prefix in instructions | Automatic plugin |
| Headless resume | `claude --resume <id> --print` | `codex exec resume <id>` | `agy --conversation <id> --print` | `kimi --session <id> -p` | Not integrated | `opencode run --session <id>` |
| Resume in a fresh session ([`resume-session`](../skills/resume-session/)) | Reads its transcripts; can be the target | Reads its transcripts; can be the target | Reads its CLI transcripts; can be the target | Target only; its sessions get the repository-only summary | Reads its transcripts; can be the target | Reads its database; can be the target |

## Claude Code

The reference harness. Skills live in the hub at `~/.claude/skills`, which the other harnesses reach through links. Hooks are shell commands registered in `settings.json`. A `PostToolUse` hook that exits with code `2` sends its message back to the model, which is how the [Mermaid validator](../hooks/validate-mermaid/) works.

## Codex

Reads `AGENTS.md` for instructions and `~/.agents/skills` for skills. `~/.codex/skills` holds Codex's own bundled skills and is not linked to the hub. RTK rewrites commands through `rtk hook codex`, which the synchronizer registers in `~/.codex/hooks.json`. Headless resume uses `codex exec resume <id> -`, reading the prompt from standard input.

## Antigravity

Google's agent, with an IDE and a command-line tool, `agy`. Skills load from `~/.gemini/config/skills`. The command-line tool also documents `~/.gemini/antigravity-cli/skills`, which the synchronizer does not link. Antigravity stops reading instructions after 24,023 characters. Some plugins come bundled. Models are chosen by hand with `/model`. RTK rewrites commands through `rtk hook antigravity`, which the synchronizer registers in `~/.gemini/config/hooks.json`. See the [Antigravity model and quota guide](../guides/guide-agy-model-and-quota-selection.md).

## Kimi Code (recorded 2026-07-28)

- **Instructions and skills without extra setup.** Reads `~/.agents/AGENTS.md`, the project's `AGENTS.md` and `~/.agents/skills` natively.
- **Hooks can block but not rewrite**, so RTK runs through instructions. See [harness hooks](reference-harness-hooks.md).
- **Headless resume.** `kimi --session session_<id> -p` approves actions automatically. Kimi has no registry of running sessions, and resuming a session that is open in the terminal sends the prompt into that live session, so `schedule-resume` warns about it.
- **Plugins.** Install from Kimi's plugin marketplace and update through `/plugins`.

## Grok Build TUI (recorded 2026-08-17)

- **Instructions and skills without extra setup.** Its Claude compatibility setting loads `~/.claude/CLAUDE.md` and the skill hub.
- **Its own hooks, not Claude's.** Loading Claude hook scripts is turned off. What each event can do is in [harness hooks](reference-harness-hooks.md), and installation is in [Grok Build TUI hooks](../hooks/README.md#grok-build-tui).
- **RTK through instructions.** There is no `rtk init` option for Grok.
- **MCP servers.** Inherits servers configured for Claude Code, and declares others in `~/.grok/config.toml`.

## OpenCode (recorded 2026-09-23, versions 2.0.14 and 1.18.32)

- **Instructions: `AGENTS.md` only on 2.x.** Both versions read `AGENTS.md` natively at `~/.config/opencode/AGENTS.md` and project level, and load both `~/.claude/skills` and `~/.agents/skills`. OpenCode 2.x no longer falls back to `CLAUDE.md` and accepts but does not load the `instructions` config array.
- **Skills and the `/` menu.** Version 1.18.x left skills out of its slash picker and offered a `/skills` browser instead (checked 1.18.21 on 2026-08-22), so the synchronizer writes one command file per skill into `~/.config/opencode/command/`, giving each skill a `/name` entry. OpenCode 2.x documents a `slash` frontmatter field that controls a skill's presence in interactive command catalogs. Both versions discover `command/`, which 2.x calls a legacy alias for `commands/`.
- **Hooks are JavaScript plugins with two API shapes.** On 2.x a plugin default-exports a definition with `id` and `setup`, registers hooks with `ctx.tool.hook("execute.before", ...)`, and refuses a call by throwing. On 1.x the entrypoint returns a hooks map keyed `tool.execute.before`, and object entrypoints are supported from 1.18.29. `tool.execute.after` cannot block on either. One module serves both with a dual entrypoint: `id` plus `setup` for 2.x, `server()` for 1.x.
- **RTK** installs its plugin with `rtk init -g --opencode`. Checked 2026-09-23: that plugin is V1-format and fails to load on OpenCode 2.x, which reports `Plugin must export a default definition`.
- **Plugins** install from one `plugin` entry per package, npm or Git. On 2.x the config key is `plugins`, and `plugin` is still accepted.
- **Model-dependent tool sets on 2.x.** Supported GPT models get the `patch` tool instead of `write` and `edit`, so a guard built on `write` and `edit` does not see their file writes (checked 2026-09-23).
- **Headless resume.** `opencode run` accepts `--session`, `--continue`, `--fork`, `--dir` and `--auto`. `--fork` resumes into a copy, which avoids taking over a session that is still open.
- **Worktrees** go outside the repository, under `~/.local/share/opencode/worktree/<project-id>/<branch>/` on 1.x. OpenCode 2.x adds a `worktree.directory` setting that moves the parent directory.

## Routing and review add-ons

Third-party tools that route prompts between models or add multi-model review. Recorded in 2026, and not integrated with this toolkit.

| Tool | What it does | Picks a model per task |
|---|---|---|
| Superpowers | Process skills: test-driven development, planning, verification, review | No |
| Claude Octopus | Multi-CLI workflows and a review panel using other models' CLIs | No |
| llm-router | Classifies each prompt and routes it to a CLI | Yes, per prompt |
| BrokeLLM | A proxy that routes by quota and model lane | Yes, per lane |
| lite-harness | One API across several harnesses | No |
