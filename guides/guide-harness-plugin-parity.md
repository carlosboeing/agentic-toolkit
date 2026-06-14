---
title: Harness plugin and skill parity (Claude Code → Antigravity)
type: guide
scope: [harness-parity, plugins, skills, antigravity, cursor]
last_reviewed: 2026-06-14
related:
  - guide-cross-harness-project-instructions.md
  - reference/reference-harness-capability-map.md
  - reference/reference-claude-code-plugins.md
---

# Harness plugin and skill parity

How to get a similar **methodology and tooling** bar when switching between Claude Code, Cursor, and Antigravity (`agy`). Prefer **official installs**; use symlinks only for portable skills (see discovery doc).

## Install channels on Antigravity

| Channel | Command / path |
|---------|----------------|
| Native plugin | `agy plugin install <url>` |
| Import Gemini extensions | `gemini extensions install …` then `agy plugin import gemini` |
| Import Claude plugins | `agy plugin import claude` (when local Claude extensions exist) |
| Skills | `~/.agents/skills/` (global), `.agents/skills/` (project) |
| MCP | `~/.gemini/config/mcp_config.json` |
| Google bundled | `~/.gemini/config/plugins/` (chrome-devtools, modern-web-guidance, …) |

Verify: `agy plugin list`, `/skills` in session, `ls ~/.agents/skills/`.

## Minimum viable set (autonomous coding runs)

Evidence from Penmark v0.5: Superpowers + shell gates do ~90% of the work; Octo was never load-bearing.

| Priority | Capability | Official Agy path |
|----------|------------|-------------------|
| P0 | Superpowers | `agy plugin install https://github.com/obra/superpowers` |
| P1 | ui-ux-pro-max | `npm i -g uipro-cli` → `uipro init --ai antigravity` in repo |
| P2 | Context7 | `npx ctx7 setup --mcp --antigravity` (or `--cli --antigravity`) |
| P2 | claude-mem | `npx claude-mem install` (pick Gemini CLI in picker) + MCP |
| P3 | Playwright MCP | Add `@playwright/mcp` to `mcp_config.json` (optional if shell Docker goldens suffice) |
| P3 | Browser live debug | **chrome-devtools-plugin** (Google bundled; replaces superpowers-chrome) |

## Claude Code plugins → Antigravity

Legend: **Official** | **Substitute** | **MCP** | **Symlink skill** | **Skip**

| Claude / Cursor plugin | Agy approach |
|------------------------|--------------|
| superpowers | **Official** — see P0 |
| ui-ux-pro-max | **Official** — uipro |
| context7 | **Official** — ctx7 setup |
| claude-mem | **Official** — install + MCP |
| playwright | **MCP** — `@playwright/mcp` |
| superpowers-chrome | **Substitute** — chrome-devtools-plugin |
| frontend-design | **Import** (`agy plugin import claude`) or **Symlink** / use **impeccable** |
| code-review, pr-review-toolkit, feature-dev | **Substitute** — Superpowers review / brainstorming skills |
| elements-of-style | **Symlink skill** from `~/.claude/skills/` if desired |
| graphify, briefing, learn | **Symlink skill** — personal skills, no official plugin |
| octo | **Skip** — no port; multi-model review optional only |
| financial-* (6 plugins) | **Skip** unless doing IB work in Agy |
| continual-learning (Cursor) | **Skip** — Cursor-only hooks |
| Claude-only (playground, output-style, agent-sdk-dev, …) | **Skip** |

## Third-party routers (optional)

Not plugins — sit **under** or **beside** the harness:

- **llm-router** — prompt classification + hooks (Gemini CLI documented; verify Agy)
- **BrokeLLM** — slot lanes (sonnet/opus/haiku) + quota-aware harness mode
- **lite-harness** — unified API across claude-code / codex (no Agy yet)

Use when you want **dynamic** per-prompt routing; use **reference-workflow** `modelRouting` for **orchestrator-level** rules.

## Symlink rules of thumb

**Do symlink:** instruction files; stable personal skills (`~/.claude/skills/X` → `~/.agents/skills/X`).

**Do not symlink:** full plugin directories from Cursor cache (hash paths break); MCP config; Superpowers twice.

For Agy **slash menu**, also link to `~/.gemini/antigravity-cli/skills/` if skills don’t appear under `/skills`.

## Project-specific run prompts

Keep run prompts (e.g. “autonomous v0.5 until tag X”) in **each app repo**. Link to this guide for harness setup — don’t duplicate the matrix per project.

## See also

- [Cross-harness instructions](guide-cross-harness-project-instructions.md)
- [Agy models and quotas](guide-agy-model-and-quota-selection.md)
- [Capability map](../reference/reference-harness-capability-map.md)
