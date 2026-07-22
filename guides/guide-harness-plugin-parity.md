---
title: Harness plugin and skill parity (Claude Code → Antigravity)
type: guide
scope: [harness-parity, plugins, skills, antigravity, claude-code, codex, cursor]
last_reviewed: 2026-07-11
last_audited: 2026-07-11
related:
  - guide-browser-automation-mcp-vs-cli.md
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

## Verified installed state (audited 2026-06-14)

### MCP servers

Configured in `~/.gemini/config/mcp_config.json`.

| Server | Type | Tools | Notes |
|--------|------|-------|-------|
| `claude-mem` | HTTP (lazy) | 19 | Memory/observations/corpus |
| `context7` | HTTP (lazy) | 2 | `resolve-library-id`, `query-docs` |
| `headroom` | stdio (lazy) | 3 | Context compression (compress/retrieve/stats) |
| `fathom` | HTTP (lazy) | 4 | Fathom meeting capture (list/search meetings, get summary/transcript) |

### CLI Proxies & Token Optimizers

| Tool | Hook Type | Mapped Harnesses | Notes |
|------|-----------|------------------|-------|
| `rtk` | Pre-execution hooks & instructions | Claude Code, Antigravity (`agy`), Cursor, Codex, OpenCode | CLI proxy that intercepts and compresses command outputs to save 60–90%+ context tokens. |

### Bundled plugins (`~/.gemini/config/plugins/`)

Ship with Antigravity; always active.

| Plugin | Key skills | Typical relevance |
|--------|-----------|-------------------|
| `superpowers` | brainstorming, TDD, plans, verification, code review, subagent-driven-dev, git worktrees, writing-skills | Critical |
| `chrome-devtools-plugin` | chrome-devtools, a11y-debugging, debug-optimize-lcp, memory-leak-debugging, troubleshooting | Medium (browser automation) |
| `frontend-design` | frontend-design | Medium |
| `modern-web-guidance-plugin` | modern-web-guidance, chrome-extensions | Medium |
| `firebase` | firestore, auth, hosting, app-hosting, data-connect, crashlytics, remote-config, security-rules-auditor | Project-dependent |
| `google-antigravity-sdk` | google-antigravity-sdk | Low |
| `android-cli-plugin` | android-cli | Project-dependent |
| `science` | 70+ bioinformatics skills | Project-dependent |

### Global skills (`~/.gemini/config/skills/`)

| Skill | Source |
|-------|--------|
| `graphify` | Installed directly (32 KB SKILL.md + references/) |

### Agent skills (`~/.agents/skills/`)

Cross-harness skills available to any agent harness reading this directory.

| Skill | Type | Source |
|-------|------|--------|
| `briefing` | Symlink | `~/.claude/skills/briefing` (added 2026-06-14) |
| `capture-meeting` | Symlink | `~/.claude/skills/capture-meeting` (added 2026-06-18) |
| `externalize-deliverable` | Symlink | `~/.claude/skills/externalize-deliverable` (added 2026-06-18) |
| `penmark-comments` | Symlink | `~/.claude/skills/penmark-comments` → `~/Projects/agentic-toolkit/skills/penmark-comments` (canonical resource bundle) |
| `ui-ux-pro-max` | Directory | Installed via `uipro` |
| `impeccable` | Directory | Manual install |
| `find-skills` | Directory | Manual install |
| `web-design-guidelines` | Directory | Manual install |
| `deploy-to-vercel` | Directory | Manual install |
| `vercel-cli-with-tokens` | Directory | Manual install |
| `vercel-composition-patterns` | Directory | Manual install |
| `vercel-react-best-practices` | Directory | Manual install |
| `vercel-react-native-skills` | Directory | Manual install |

## Minimum viable set (autonomous coding runs)

Evidence from a long autonomous run (2026-06): Superpowers + shell gates do ~90% of the work; Octo was never load-bearing.

| Priority | Capability | Official Agy path |
|----------|------------|-------------------|
| P0 | Superpowers | Bundled at `~/.gemini/config/plugins/superpowers` (full skill set); fresh install: `agy plugin install https://github.com/obra/superpowers` |
| P1 | ui-ux-pro-max | `npm i -g uipro-cli` → `uipro init --ai antigravity` in repo |
| P2 | Context7 | MCP in `mcp_config.json` (or `npx ctx7 setup --mcp --antigravity` / `--cli --antigravity`) |
| P2 | claude-mem | MCP in `mcp_config.json` (or `npx claude-mem install`, pick Gemini CLI in picker) |
| P3 | Playwright MCP | Required alongside the Playwright CLI for Claude Code, Codex, and Antigravity parity; configure only after inspection using the [shared baseline](guide-browser-automation-mcp-vs-cli.md#cross-harness-playwright-baseline) |
| P3 | Browser live debug | **chrome-devtools-plugin** (Google bundled; replaces superpowers-chrome) |

## Claude Code plugins → Antigravity

Legend: **Official** | **Substitute** | **MCP** | **Symlink skill** | **Skip**

| Claude / Cursor plugin | Agy approach |
|------------------------|--------------|
| superpowers | **Official** — bundled (full skill set); fresh install: `agy plugin install https://github.com/obra/superpowers` |
| ui-ux-pro-max | **Official** — uipro |
| context7 | **Official** — already wired as MCP; fresh: `npx ctx7 setup --mcp --antigravity` |
| claude-mem | **Official** — already wired as MCP; fresh: `npx claude-mem install` (pick Gemini CLI) |
| playwright | **MCP + CLI** — `@playwright/mcp` and Playwright CLI (`@playwright/test`) are both required for Claude Code, Codex, and Antigravity parity; chrome-devtools-plugin remains an additional Agy live-debug tool. Run the [shared smoke procedure](guide-browser-automation-mcp-vs-cli.md#shared-smoke-procedure). |
| superpowers-chrome | **Substitute** — chrome-devtools-plugin |
| frontend-design | **Import** (`agy plugin import claude`) or **Bundled** at `~/.gemini/config/plugins/frontend-design` |
| code-review, pr-review-toolkit, feature-dev | **Substitute** — Superpowers review / brainstorming / subagent skills |
| elements-of-style | **Symlink skill** from `~/.claude/skills/` if desired; low priority |
| graphify | **Installed** — `~/.gemini/config/skills/graphify` |
| briefing | **Symlink skill** — `~/.agents/skills/briefing` → `~/.claude/skills/briefing` |
| capture-meeting | **Symlink skill** — `~/.agents/skills/capture-meeting` → `~/.claude/skills/capture-meeting` |
| externalize-deliverable | **Symlink skill** — `~/.agents/skills/externalize-deliverable` → `~/.claude/skills/externalize-deliverable` |
| penmark-comments | **Symlink skill** — `~/.claude/skills/penmark-comments` and `~/.agents/skills/penmark-comments` directly target `~/Projects/agentic-toolkit/skills/penmark-comments`, the canonical resource bundle. [`sync-skills.sh`](../skills/sync-skills.sh) maintains this one-source model for Claude, Codex, and Agy. See the [integration guide](guide-penmark-agent-integration.md) for validation and the deferred cross-harness audit. |
| learn | **Symlink skill** from `~/.claude/skills/learn` if desired |
| octo | **Skip** — no port; multi-model review optional only |
| financial-* (6 plugins) | **Skip** unless doing IB work in Agy |
| continual-learning (Cursor) | **Skip** — Cursor-only hooks |
| Claude-only (playground, output-style, agent-sdk-dev, …) | **Skip** |

## Browser automation: MCP vs CLI vs chrome-devtools

Keep **both** Playwright MCP and the Playwright CLI; choose **per job**, not one globally. Full decision guide with the reasoning, token-cost truth, and corrected myths: [`guide-browser-automation-mcp-vs-cli.md`](guide-browser-automation-mcp-vs-cli.md).

| Tool | Use for | Per harness |
|---|---|---|
| **Playwright MCP** (`@playwright/mcp`) | Exploratory / ad-hoc / web browsing / live aesthetic review — the interactive REPL loop | Claude Code, Codex, Antigravity (required for parity); Cursor |
| **Playwright CLI** (`@playwright/test`) | Repeatable flows, visual-regression goldens, anything committed or re-run | Claude Code, Codex, Antigravity (required for parity); Cursor |
| **chrome-devtools-plugin** (Agy bundled) | Additional live debugging / exploratory tool in Antigravity (replaces superpowers-chrome); it does not replace the MCP parity check | Antigravity |

The CLI is **`@playwright/test`** (the `playwright` binary provides `test`, `codegen`, `screenshot`, `open`) — there is no `@playwright/cli` package. MCP idle cost is harness-dependent: Claude Code can defer tool schemas (~names until first use), so "skip the MCP to save context" only holds on eager-loading harnesses. Judging *looks* needs screenshots + vision either way — the accessibility snapshot shows structure, not aesthetics. Follow the [shared smoke procedure](guide-browser-automation-mcp-vs-cli.md#shared-smoke-procedure); configuration listings alone do not establish parity.

## Third-party routers (optional)

Not plugins — sit **under** or **beside** the harness:

- **llm-router** — prompt classification + hooks (Gemini CLI documented; verify Agy)
- **BrokeLLM** — slot lanes (sonnet/opus/haiku) + quota-aware harness mode
- **lite-harness** — unified API across claude-code / codex (no Agy yet)

Use when you want **dynamic** per-prompt routing; use **reference-workflow** `modelRouting` for **orchestrator-level** rules.

## Symlink rules of thumb

**Do symlink:** instruction files; stable personal skills (`~/.claude/skills/X` → `~/.agents/skills/X`). Automate the authored-skill fan-out with [`../skills/sync-skills.sh`](../skills/sync-skills.sh) — it symlinks every authored skill from this repo straight into each installed harness's skill dir (Claude `~/.claude/skills`, Codex `~/.agents/skills`, Agy `~/.gemini/config/skills`). Independent of the `find-skills` tool.

**Do not symlink:** full plugin directories from Cursor cache (hash paths break); MCP config; Superpowers twice.

For Agy **slash menu**, also link to `~/.gemini/antigravity-cli/skills/` if skills don't appear under `/skills`.

## Useful commands

```bash
# Check plugins
agy plugin list

# Check agent skills
ls ~/.agents/skills/

# Check project-level agent config
ls .agents/

# Launch with auto-approve (no prompts)
agy --dangerously-skip-permissions

# Check MCP config (redact keys before sharing)
cat ~/.gemini/config/mcp_config.json
```

## Project-specific run prompts

Keep run prompts (e.g. "autonomous sprint until milestone X") in **each app repo**. Link to this guide for harness setup — don't duplicate the matrix per project.

## See also

- [Cross-harness instructions](guide-cross-harness-project-instructions.md)
- [Agy models and quotas](guide-agy-model-and-quota-selection.md)
- [Capability map](../reference/reference-harness-capability-map.md)
