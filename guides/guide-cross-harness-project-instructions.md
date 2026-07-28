---
title: Cross-harness project instructions (CLAUDE / AGENTS / GEMINI)
type: guide
scope: [harness-parity, claude-code, cursor, antigravity, gemini-cli, kimi-code]
authors:
  - "Carlos Boeing"
  - "gpt-5 (codex)"
  - "k3 (kimi-code)"
last_reviewed: 2026-07-28
related:
  - guide-harness-plugin-parity.md
  - guide-agy-model-and-quota-selection.md
  - templates/default-project/CLAUDE.md
---

# Cross-harness project instructions

One canonical project brief, readable by every agentic harness you use.

## Pattern

```
CLAUDE.md          ← canonical (edit this)
AGENTS.md   → CLAUDE.md    (Cursor, continual-learning)
GEMINI.md   → CLAUDE.md    (Gemini CLI, Antigravity via Superpowers)
```

Create symlinks from the repo root:

```bash
ln -sf CLAUDE.md AGENTS.md
ln -sf CLAUDE.md GEMINI.md
git add CLAUDE.md AGENTS.md GEMINI.md
```

Git records `AGENTS.md` and `GEMINI.md` as symlinks (`typechange` on first conversion).

## What to put in CLAUDE.md

Keep it **harness-neutral** in the header:

- What the project is, project map, conventions, commit style, working principles
- Optional: `## Learned User Preferences` / `## Learned Workspace Facts` (Cursor continual-learning appends here via `AGENTS.md` symlink)

Do **not** embed Claude-only slash commands as requirements unless you guard with “Claude Code only”.

## User-level defaults and project precedence

Put personal, cross-project defaults in the canonical user instruction target rather than the project brief. The global Penmark rule is one example: it selects the `penmark-comments` skill for explicit reviews of writable local Markdown files. Direct user and project instructions can override file mutation and route findings to chat without suppressing skill activation.

Keep this kind of global rule short and harness-neutral. Put workflow mechanics, dependencies, and validation in the portable skill; see [Penmark agent integration](guide-penmark-agent-integration.md). Do not add a personal global preference to a generic project template unless the project explicitly adopts it.

## Harness loading behaviour

| Harness | File read | Notes |
|---------|-----------|-------|
| Claude Code | `CLAUDE.md` | Auto-loaded every session |
| Cursor | `AGENTS.md` (+ often `CLAUDE.md`) | Workspace rules; symlink may duplicate content |
| Antigravity CLI / IDE | `GEMINI.md` | Superpowers `contextFileName`; migration docs also mention `AGENTS.md` |
| Codex | Project instructions vary | Copy or symlink per Codex project config |
| Kimi Code | `AGENTS.md` | Reads project `AGENTS.md` and the shared `~/.agents/AGENTS.md` natively — no symlink or adapter file needed; optional Kimi-specific layer at `~/.kimi-code/AGENTS.md` |

## Continual-learning (Cursor only)

Cursor’s continual-learning plugin updates **`AGENTS.md`** learned sections. With the symlink, updates land in **`CLAUDE.md`** — intentional single source of truth. No equivalent hook on Agy today; use claude-mem MCP or manual doc updates.

## Retrofit checklist

1. Merge any unique `AGENTS.md` bullets into `CLAUDE.md`
2. Generalize title (“project instructions for AI agents”)
3. Create symlinks; update README one-liner
4. Verify: `readlink AGENTS.md` → `CLAUDE.md`
5. Commit symlinks + merged content together

## When not to symlink

- **Different content per harness** (rare) — use separate files and accept drift
- **Windows contributors** without symlink support — use copy + CI check, or document Developer Mode / `core.symlinks=true`

## See also

- [Harness plugin parity](guide-harness-plugin-parity.md)
- [Default project template](../templates/default-project/CLAUDE.md)
