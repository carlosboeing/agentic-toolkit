---
title: Harness capability map — deliberation, routing, plugins
type: reference
last_reviewed: 2026-06-14
related:
  - guides/guide-harness-plugin-parity.md
  - guides/guide-agy-model-and-quota-selection.md
  - docs/2-design/2026-06-04-agent-delegation-layer-design.md
---

# Harness capability map

Quick comparison for the five concerns in [agent delegation layer design](../docs/2-design/2026-06-04-agent-delegation-layer-design.md).

## Concern matrix

| Concern | What you want | Best fit today | Notes |
|---------|---------------|----------------|-------|
| **1 — Multi-POV deliberation** | Council/debate on design docs | Superpowers brainstorming + optional native review | Octo timed out on Penmark; **no Agy port** |
| **2 — RTK / token optimization** | Smaller context | RTK hooks (independent of this doc) | Install regardless of delegation build |
| **3 — Difficulty / task routing** | easy→cheap, hard→opus | **reference-workflow** `modelRouting` | Extend with harness-specific model names |
| **4 — Capability MCP** | Vision, PDF, … | Per-server MCP in each harness | Same servers, different config files |
| **5 — Harness portability** | Same skills/instructions | Symlinks + official Agy installs | This repo’s guides |

## Tool comparison

| Tool | Primary job | Multi-model review | Per-task model pick | Agy |
|------|-------------|--------------------|---------------------|-----|
| **Superpowers** | Process discipline (TDD, plans, verify) | Via skills, not external CLIs | No | Official plugin |
| **Claude Octopus** | Multi-CLI workflows + review panel | Yes (Codex/Gemini CLI) | No (workflow-level) | **No** |
| **reference-workflow** | SDLC orchestrator + builders | Rule-based review skip/tier | **Yes** (`modelRouting`) | Manual model in Agy |
| **llm-router** | Classify prompt → route CLI | No | **Yes** (prompt-level) | Unverified |
| **BrokeLLM** | Quota-aware proxy + lanes | No | **Yes** (slot/lane) | CLI-agnostic |
| **lite-harness** | One API, multiple harnesses | No | Harness default | No Agy harness |
| **Antigravity `agy`** | Google agent CLI + IDE | Bundled plugins only | Manual `/model` only | Native |

## Penmark v0.5 — what actually mattered

| Component | Load-bearing? |
|-----------|---------------|
| Superpowers + self-review | Yes |
| vitest + eslint + Docker Playwright | Yes |
| ui-ux-pro-max / impeccable (webview UI) | Yes (R14–R15) |
| Octo | No (4/4 timeout) |
| Financial plugins | No |
| CI (GitHub Actions) | Blocked (billing) — local gates only |

## Decision pointers

- **Implementation review on a branch:** Superpowers + native high-effort review, not Octo by default.
- **Design doc council:** Superpowers brainstorming first; Octo or lean delegation only if you repeatedly want external voices.
- **Quota-aware long runs:** Agy model guide + orchestrator routing; not Octo.
- **Cross-harness same repo:** Instruction symlinks + plugin parity guide.

## Links

- [Discovery: 2026-06-14 research](../docs/1-discovery/2026-06-14-harness-parity-model-routing-research.md)
- [Claude Code plugins snapshot](reference-claude-code-plugins.md)
