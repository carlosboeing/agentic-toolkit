---
title: Harness capability map
type: reference
last_reviewed: 2026-09-22
authors:
  - "Carlos Boeing"
  - "k3 (kimi-code)"
  - "grok-4.6 (grok)"
  - "claude-opus-5 (claude-code)"
related:
  - guides/guide-harness-plugin-parity.md
  - guides/guide-ai-model-and-effort-routing.md
---

# Harness capability map

What each supported AI coding harness can do, feature by feature, as recorded when each harness was integrated with this toolkit. Product behavior changes between releases, so check the dates below and the product's own documentation before relying on a row. For installation steps, see the [new-machine setup guide](../guides/guide-new-machine-setup.md) and the [plugin parity guide](../guides/guide-harness-plugin-parity.md).

## At a glance

| Capability | Claude Code | Codex | Antigravity | Kimi Code | Grok Build TUI | OpenCode |
|---|---|---|---|---|---|---|
| Global instructions | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | `~/.gemini/GEMINI.md` | `~/.agents/AGENTS.md` | `~/.claude/CLAUDE.md` through Claude compatibility | `~/.config/opencode/AGENTS.md` |
| Skills directory | `~/.claude/skills` (the hub) | `~/.agents/skills` | `~/.gemini/config/skills` | `~/.agents/skills` | The hub, through Claude compatibility | The hub and `~/.agents/skills` |
| Hooks that can block the agent | Yes, including after a tool runs | Not used by this toolkit | Not used by this toolkit | Before a tool runs, on stop and on prompt submit | Before a tool runs and on stop | Before a tool runs |
| Hooks that can rewrite a tool call | Yes | Not used by this toolkit | Not used by this toolkit | No | Yes, before a tool runs | Yes, through a plugin |
| RTK mode | Automatic hook | `rtk` prefix in instructions | `rtk` prefix in instructions | `rtk` prefix in instructions | `rtk` prefix in instructions | Automatic plugin |
| Superpowers install | Plugin marketplace | Plugin marketplace | Bundled, or `agy plugin install` | `/plugins` marketplace | Reads Claude Code's plugins | `plugin` entry in `opencode.json` |
| Headless resume | `claude --resume <id> --print` | `codex exec resume <id>` | `agy --conversation <id> --print` | `kimi --session <id> -p` | Not integrated | `opencode run --session <id>` |

## Claude Code

The reference harness. Skills live in the hub at `~/.claude/skills`, which the other harnesses reach through links. Hooks are shell commands registered in `settings.json`. A `PostToolUse` hook that exits with code `2` sends its message back to the model, which is how the [Mermaid validator](../hooks/validate-mermaid/) works.

## Codex

Reads `AGENTS.md` for instructions and `~/.agents/skills` for skills. `~/.codex/skills` holds Codex's own bundled skills and is not linked to the hub. RTK runs through an instruction to prefix commands with `rtk`. Headless resume uses `codex exec resume <id> -`, reading the prompt from standard input.

## Antigravity

Google's agent, with an IDE and a command-line tool, `agy`. Skills load from `~/.gemini/config/skills`. The command-line tool also documents `~/.gemini/antigravity-cli/skills`, which the synchronizer does not link. Antigravity stops reading instructions after 24,023 characters. Some plugins, including Superpowers, come bundled. Models are chosen by hand with `/model`. See the [Antigravity model and quota guide](../guides/guide-agy-model-and-quota-selection.md).

## Kimi Code (recorded 2026-07-28)

- **Instructions and skills without extra setup.** Reads `~/.agents/AGENTS.md`, the project's `AGENTS.md` and `~/.agents/skills` natively.
- **Hooks can block but not rewrite.** `PreToolUse`, `Stop` and `UserPromptSubmit` can block. `PostToolUse` only observes, and no hook can change a tool's input, so RTK runs through instructions.
- **Headless resume.** `kimi --session session_<id> -p` approves actions automatically. Kimi has no registry of running sessions, and resuming a session that is open in the terminal sends the prompt into that live session, so `schedule-resume` warns about it.
- **Plugins.** Superpowers installs from Kimi's plugin marketplace and updates through `/plugins`.

## Grok Build TUI (recorded 2026-08-17)

- **Instructions and skills without extra setup.** Its Claude compatibility setting loads `~/.claude/CLAUDE.md` and the skill hub.
- **Its own hooks, not Claude's.** `PreToolUse` can deny and rewrite, and `Stop` can block. Loading Claude hook scripts is turned off. `PostToolUse` results never reach the model. See [Grok Build TUI hooks](../hooks/README.md#grok-build-tui).
- **RTK through instructions.** There is no `rtk init` option for Grok.
- **MCP servers.** Inherits servers configured for Claude Code, and declares others in `~/.grok/config.toml`.
- **Superpowers.** Uses Claude Code's plugin copy. Do not install a second one.

## OpenCode (recorded 2026-08-19, version 1.18.18)

- **Instructions and skills without extra setup.** Reads `AGENTS.md` natively and loads both `~/.claude/skills` and `~/.agents/skills`.
- **Skills are not in the `/` menu.** The terminal interface leaves skills out of its slash picker, and offers a `/skills` browser and Ctrl+P instead (checked against version 1.18.21 on 2026-08-22). The synchronizer writes one small command file per skill into `~/.config/opencode/command/`, so each skill gets a `/name` command.
- **Hooks are JavaScript plugins.** `tool.execute.before` can refuse a call by throwing, which stops a bad write before it happens. `tool.execute.after` cannot block.
- **RTK rewrites commands automatically** after `rtk init -g --opencode` installs its plugin.
- **Superpowers installs natively** from one `plugin` entry that points at the upstream Git repository.
- **Headless resume.** `opencode run` accepts `--session`, `--continue`, `--fork`, `--dir` and `--auto`. `--fork` resumes into a copy, which avoids taking over a session that is still open.
- **Worktrees** go outside the repository, under `~/.local/share/opencode/worktree/<project-id>/<branch>/`.

## Routing and review add-ons

Third-party tools that route prompts between models or add multi-model review. Recorded in 2026, and not integrated with this toolkit.

| Tool | What it does | Picks a model per task |
|---|---|---|
| Superpowers | Process skills: test-driven development, planning, verification, review | No |
| Claude Octopus | Multi-CLI workflows and a review panel using other models' CLIs | No |
| llm-router | Classifies each prompt and routes it to a CLI | Yes, per prompt |
| BrokeLLM | A proxy that routes by quota and model lane | Yes, per lane |
| lite-harness | One API across several harnesses | No |
