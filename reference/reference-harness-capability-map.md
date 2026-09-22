---
title: Harness capability map — deliberation, routing, plugins
type: reference
last_reviewed: 2026-08-19
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

This is a capability snapshot from the dated integrations below, not a live inventory. Product versions, plugin paths, model access, provider counts, and quotas may have changed. For installation, use the [current setup guide](../guides/guide-new-machine-setup.md) and verify the installed product's documentation.

Quick comparison for the five core concerns across agent delegation and task routing.

## Concern matrix

| Concern | What you want | Best fit today | Notes |
|---------|---------------|----------------|-------|
| **1 — Multi-POV deliberation** | Council/debate on design docs | Superpowers brainstorming + optional native review | Octo timed out in production trial; **no Agy port** |
| **2 — RTK / token optimization** | Smaller context | RTK hooks (independent of this doc) | Install regardless of delegation build |
| **3 — Difficulty / task routing** | easy→cheap, hard→opus | SDLC orchestrator `modelRouting` | Extend with harness-specific model names |
| **4 — Capability MCP** | Vision, PDF, … | Per-server MCP in each harness | Same servers, different config files |
| **5 — Harness portability** | Same skills/instructions | Symlinks + official Agy installs | This repo’s guides |

## Tool comparison

| Tool | Primary job | Multi-model review | Per-task model pick | Agy |
|------|-------------|--------------------|---------------------|-----|
| **Superpowers** | Process discipline (TDD, plans, verify) | Via skills, not external CLIs | No | Official plugin |
| **Claude Octopus** | Multi-CLI workflows + review panel | Yes (Codex/Gemini CLI) | No (workflow-level) | **No** |
| **SDLC orchestrator** | SDLC orchestrator + builders | Rule-based review skip/tier | **Yes** (`modelRouting`) | Manual model in Agy |
| **llm-router** | Classify prompt → route CLI | No | **Yes** (prompt-level) | Unverified |
| **BrokeLLM** | Quota-aware proxy + lanes | No | **Yes** (slot/lane) | CLI-agnostic |
| **lite-harness** | One API, multiple harnesses | No | Harness default | No Agy harness |
| **Antigravity `agy`** | Google agent CLI + IDE | Bundled plugins only | Manual `/model` only | Native |

## Autonomous run evidence (2026-06 trial)

| Component | Load-bearing? |
|-----------|---------------|
| Superpowers + self-review | Yes |
| Shell test gates (build, lint, unit, browser goldens) | Yes |
| ui-ux-pro-max / impeccable (UI-heavy work) | Yes |
| Octo | No (4/4 timeout) |
| Financial plugins | No |
| Remote CI | Optional — local gates sufficient when CI unavailable |

## Kimi Code (added 2026-07-28)

Fourth harness, alongside Claude Code, Codex, and Agy. The load-bearing capabilities, verified against the official docs and live probes during Kimi parity integration:

- **Instructions and skills for free** — reads `~/.agents/AGENTS.md`, project `AGENTS.md`, and `~/.agents/skills/` natively; no symlinks or fan-out needed.
- **Hooks gate but don't rewrite** — PreToolUse/Stop/UserPromptSubmit can block; PostToolUse is observation-only; no `tool_input` mutation, so RTK-style transparent command rewriting is impossible (RTK runs in instructions mode, like Codex).
- **Headless resume** — `kimi --session session_<id> -p` auto-approves; no session PID registry, and resuming an open session injects into it (schedule-resume warns at create).
- **Native plugin system** — superpowers installs from the marketplace (`.kimi-plugin/plugin.json`), updated via `/plugins`, not the canonical-clone model.
- **Models** — K3 (up to 1M context, T1–T2), K2.7 Coding (T1), Highspeed variants (T0–T1); membership-plan quota, independent pool.

## Grok Build TUI (added 2026-08-17)

Fifth daily harness, alongside Claude Code, Codex, Agy, and Kimi. Cursor is parked. Load-bearing facts verified during Grok parity integration:

- **Instructions and skills for free** — Claude compat loads `~/.claude/CLAUDE.md` and the `~/.claude/skills` hub. No Grok spoke.
- **Hooks: ingest off** — PreToolUse can deny and rewrite, Stop can block, but we do not ingest Claude hook scripts. PostToolUse is observe-only even if ingest returns.
- **RTK is the prefix path** — no `rtk init --agent grok`. Same instruction class as Codex and Kimi.
- **MCP** — inherit Fathom, `mcp-image`, chrome, `mcp-search`; declare `claude-mem`, Playwright, Context7 in `~/.grok/config.toml`.
- **Superpowers** — Claude plugin path. Do not install a second tree.
- **Not in this pass** — no CrossRev grok adapter, no `schedule-resume` grok target, no output styles, no briefing probe of Grok memory.

## OpenCode (added 2026-08-19)

Sixth daily harness, alongside Claude Code, Codex, Antigravity, Kimi, and Grok. Cursor stays parked. Facts verified during OpenCode parity integration, measured against version 1.18.18:

- **Instructions and skills for free** — reads `AGENTS.md` natively and auto-loads both `~/.claude/skills` and `~/.agents/skills`. No spoke, no symlink.
- **Skills are model-invoked, not slash-invoked** (verified against v1.18.21 source, 2026-08-22) — the TUI `/` picker deliberately filters out skill-sourced commands (`footer.prompt.tsx`: `item.source !== "skill"`); the native entry points are a `/skills` browser dialog and Ctrl+P → Skills. Workaround for per-skill `/name` access: one thin command file per skill in `~/.config/opencode/command/` whose body invokes the skill via the skill tool with `$ARGUMENTS` (also dodges the upstream bug where slash-invoked skills swallow trailing arguments); generated by `skills/sync-skills.sh` on every sync. The v2 desktop app shows skills in `/` natively with a badge; the classic TUI keeps the filter even on the `dev` branch. Skill discovery paths and the `SKILL.md` format are unchanged in v2 — no migration.
- **Hooks are JavaScript** — plugin modules, not shell scripts. `tool.execute.before` refuses a call when the handler throws, so a bad write is stopped before it happens. `tool.execute.after` documents no blocking. Stronger than Kimi and Grok, which cannot refuse a write at all.
- **RTK rewrites transparently** — `rtk init -g --opencode` installs a plugin. Same class as Claude Code and Cursor, not the instruction class.
- **Superpowers installs natively** — one `plugin` entry pointing at the upstream git spec. Verified 2026-08-19: the skill count moved from 36 to 50 with all 14 Superpowers skills registered.
- **Headless resume is the most complete of the six** — `opencode run` accepts `--session`, `--continue`, `--fork`, `--dir`, and `--auto`. It also takes `--format json` and `--variant`. `--fork` removes the live-session takeover hazard the Kimi target carries.
- **Provider-agnostic** — 192 providers. Three subscriptions are reachable: ChatGPT Plus/Pro, SuperGrok, and Kimi For Coding. Claude Pro/Max is prohibited by Anthropic, and both Gemini OAuth routes are dead.
- **Native worktrees sit outside the repository** — `~/.local/share/opencode/worktree/<project-id>/<branch>/`. Documented, not relocated, as with Grok.
- **Not in this pass** — no CrossRev leg, no memory, no output styles, and no plugin-bundled Anthropic skills.

## Decision pointers

- **Implementation review on a branch:** Superpowers + native high-effort review, not Octo by default.
- **Design doc council:** Superpowers brainstorming first; Octo or lean delegation only if you repeatedly want external voices.
- **Quota-aware long runs:** Agy model guide + orchestrator routing; not Octo.
- **Cross-harness same repo:** Instruction symlinks + plugin parity guide.

## Links

- [Cross-harness model comparison](reference-cross-harness-models.md)
- [Claude Code plugins snapshot](reference-claude-code-plugins.md)
