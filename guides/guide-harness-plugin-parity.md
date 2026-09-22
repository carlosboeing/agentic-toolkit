---
title: Harness plugin and skill parity (Claude Code, Codex, Antigravity, Kimi, Grok)
type: guide
scope: [harness-parity, plugins, skills, antigravity, claude-code, codex, cursor, kimi-code, grok]
last_reviewed: 2026-08-25
last_audited: 2026-07-28
authors:
  - "Carlos Boeing"
  - "k3 (kimi-code)"
  - "grok-4.6 (grok)"
  - "gemini-3.7-flash (agy)"
related:
  - guide-browser-automation-mcp-vs-cli.md
  - guide-cross-harness-project-instructions.md
  - reference/reference-harness-capability-map.md
  - reference/reference-claude-code-plugins.md
---

# Harness plugin and skill parity

How to get a similar **methodology and tooling** bar when switching between Claude Code, Codex, Antigravity (`agy`), Kimi Code, and Grok Build TUI. Cursor is parked. Prefer **official installs**; use symlinks only for portable skills (see the topology and parity guides).

## Install channels on Antigravity

| Channel | Command / path |
|---------|----------------|
| Native plugin | `agy plugin install <url>` |
| Import Gemini extensions | `gemini extensions install …` then `agy plugin import gemini` |
| Import Claude plugins | `agy plugin import claude` (when local Claude extensions exist) |
| Skills | `.agents/skills/` (project); `~/.gemini/config/skills/` (IDE/2.0 global); `~/.gemini/antigravity-cli/skills/` (CLI global). The synchronizer creates only the IDE/2.0 spoke. [Official locations](https://antigravity.google/docs/skills), checked 2026-09-22. |
| MCP | `~/.gemini/config/mcp_config.json` |
| Google bundled | `~/.gemini/config/plugins/` (chrome-devtools, modern-web-guidance, …) |

Verify: `agy plugin list`, `/skills` in session, `ls ~/.agents/skills/`.

## Install channels on Kimi Code

| Channel | Command / path |
|---------|----------------|
| Native plugin | `/plugins` marketplace, or `/plugins install <github-url>` |
| Skills | `~/.agents/skills/` (shared, read natively — a whole-dir symlink to the hub since 2026-08-06), `.agents/skills/` + `.kimi-code/skills/` (project). `~/.kimi-code/skills/` was removed as redundant; recreate it only for a genuinely Kimi-specific skill |
| Instructions | `~/.agents/AGENTS.md` + project `AGENTS.md` (read natively — no symlink needed); optional Kimi-specific `~/.kimi-code/AGENTS.md` |
| MCP | `~/.kimi-code/mcp.json` (+ project `.kimi-code/mcp.json`); manage interactively with `/mcp-config` |
| Hooks | `[[hooks]]` in `~/.kimi-code/config.toml` — only PreToolUse, Stop, and UserPromptSubmit can block, and no event can rewrite tool input |
| Headless | `kimi --session session_<id> -p` (auto-approves; `-p` rejects `--yolo`/`--auto`) |

Kimi reads the shared `~/.agents/` layer natively, so the hub-and-spoke topology and the canonical instruction file already cover it with zero wiring — `~/.agents/skills` is a symlink to the hub. Verify: `ls ~/.agents/skills/`, `/plugins info <name>`, `kimi doctor`.

## Install channels on Grok Build TUI

| Channel | Command / path |
|---------|----------------|
| Skills | `~/.claude/skills` via `[compat.claude] skills = true`. No `~/.grok/skills` spoke |
| Instructions | `~/.claude/CLAUDE.md` via `[compat.claude] agents = true`. Project `AGENTS.md` natively. No `~/.grok/AGENTS.md` |
| MCP inherit | Claude MCP (`fathom`, `mcp-image`, claude-mem plugin `mcp-search`, chrome) |
| MCP declared | `~/.grok/config.toml`: `claude-mem`, Playwright (`--isolated`), Context7 (`Authorization = Bearer ${CONTEXT7_API_KEY}`) |
| Hooks | Claude hook ingest **off**. Owned PreToolUse/Stop hooks register natively under `~/.grok/hooks/`. Do not shim inherited Claude plugin hooks. See [`hooks/README.md`](../hooks/README.md#grok-build-tui) |
| Plugins | Claude discovery on; `[plugins].disabled` mirrors Claude's off list |
| Superpowers | Claude plugin path to the canonical clone. Do not `grok plugin install` a second tree |

## Install channels on OpenCode

| Channel | Command / path |
|---------|----------------|
| Skills | `~/.claude/skills` and `~/.agents/skills`, auto-loaded. No OpenCode spoke needed |
| Instructions | `AGENTS.md` natively, at global and project scope |
| Config | `~/.config/opencode/opencode.json`. Not `~/.opencode/`, which holds only the binary |
| MCP | `mcp` block in `opencode.json`. `enabled: false` turns off a server inherited from a parent config |
| Hooks | No shell hooks. JavaScript plugin modules, auto-loaded from `~/.config/opencode/plugins/` or declared in the `plugin` array. `tool.execute.before` refuses a call by throwing; `tool.execute.after` documents no blocking |
| Mermaid | `sync-skills.sh` copies `hooks/validate-mermaid/opencode-validate-mermaid.ts` to `plugins/validate-mermaid.ts` |
| Plugins | `plugin` array accepts npm and git specs. Loose files in `plugins/` load without a config entry |
| Superpowers | `"plugin": ["superpowers@git+https://github.com/obra/superpowers.git"]`. Do not symlink — upstream deprecated that path |
| RTK | `rtk init -g --opencode` writes `~/.config/opencode/plugins/rtk.ts` |
| Providers | `disabled_providers` switches off a registry provider that a stray environment variable enabled |
| Agents and commands | `~/.config/opencode/agent/<name>.md` and `command/<name>.md`, Markdown with frontmatter |

## Verified installed state — Kimi (audited 2026-07-28)

| Piece | State |
|-------|-------|
| Authored skills (briefing, penmark-comments, schedule-resume, …) | Reached through `~/.agents/skills`, a whole-dir symlink to the hub — no Kimi-specific step. **Changed 2026-08-06:** they are copies in the hub now, not live symlinks into the repo, so a repo edit needs `sync-skills.sh` before Kimi sees it |
| `kimi-webbridge` skill | **Removed 2026-08-06** from all four locations, pending reinstall. `~/.kimi-code/skills` was deleted with it. Rebuild path in [`reference-third-party-skills.md`](../reference/reference-third-party-skills.md) |
| MCP servers (context7, claude-mem, fathom, playwright) | Parity target: mirror the four entries from `~/.gemini/config/mcp_config.json` into `~/.kimi-code/mcp.json`. `headroom` was a fifth until 2026-08-04 — do not re-add it, see [ADR 0001](../docs/adrs/0001-remove-headroom-compression-proxy.md) |
| Superpowers | Historical setup, superseded 2026-08-19. Use native `/plugins install` and the report from [`install-superpowers.sh`](../plugins/install-superpowers.sh); the local clone and relinker are retired. |
| RTK | Instructions mode (`rtk init --agent kimi`, needs rtk ≥ 0.44.0) — Kimi hooks can't rewrite tool input, so no transparent hook |

## Verified installed state — Antigravity (audited 2026-06-14)

### MCP servers

Configured in `~/.gemini/config/mcp_config.json`.

| Server | Type | Tools | Notes |
|--------|------|-------|-------|
| `claude-mem` | HTTP (lazy) | 19 | Memory/observations/corpus |
| `context7` | HTTP (lazy) | 2 | `resolve-library-id`, `query-docs` |
| `headroom` | stdio (lazy) | 3 | Context compression (compress/retrieve/stats). **Removed 2026-08-04** — [ADR 0001](../docs/adrs/0001-remove-headroom-compression-proxy.md); row kept because this table is a dated audit snapshot |
| `fathom` | HTTP (lazy) | 4 | Fathom meeting capture (list/search meetings, get summary/transcript) |

### CLI Proxies & Token Optimizers

| Tool | Hook Type | Mapped Harnesses | Notes |
|------|-----------|------------------|-------|
| `rtk` | Pre-execution hooks & instructions | Claude Code, Cursor, OpenCode (transparent hooks); Antigravity (`agy`), Codex, Kimi, Grok (instructions mode) | CLI proxy that intercepts and compresses command outputs to save 60–90%+ context tokens. Claude Code, Cursor and OpenCode rewrite transparently; the rest use explicit prefix instructions. OpenCode moved to the transparent group on 2026-08-19 when `rtk init -g --opencode` was verified to write `~/.config/opencode/plugins/rtk.ts`. |

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

### Agent skills — the hub-and-spoke model (since 2026-08-06)

Every skill physically lives in **one** place: `~/.claude/skills`, the hub. It holds real directories and nothing else, so Claude Code — the primary harness — never resolves a symlink to find a skill. Every other harness reaches the same content through a whole-directory symlink.

| Directory | Role | Serves |
|---|---|---|
| `~/.claude/skills` | **Hub** with real skill directories; counts depend on the installed set | Claude Code |
| `~/.agents/skills` | Whole-dir symlink to the hub | Codex, Kimi Code |
| `~/.gemini/config/skills` | Whole-dir symlink to the hub | Antigravity |
| `~/.codex/skills` | **Not a spoke.** Holds `.system/`, Codex's own bundled skills | Codex internals — leave alone |
| `~/.kimi-code/skills` | Removed 2026-08-06 — redundant with `~/.agents/skills` | — |

Whole-directory spokes share one installed copy. The authored source can still drift from the hub until synchronization runs. Before this, four skills existed as independent copies across harnesses and two had already diverged.

Content reaches the hub two ways:

- **Authored skills** stay canonical in `agentic-toolkit/skills/` and are copied in by [`sync-skills.sh`](../skills/sync-skills.sh). They are no longer live-edited — an edit in the repo needs a sync run before any harness sees it.
- **Third-party skills** are installed straight into the hub. Vendor CLIs that write to `~/.agents/skills` now write through the spoke symlink and land in the hub automatically. If one recreates the spoke as a real directory, `./skills/sync-skills.sh --adopt` folds it back in.

The hub is derived state and is not tracked by this repository. Recovery comes from [`reference-third-party-skills.md`](../reference/reference-third-party-skills.md), which records the rebuild command for every skill this repo does not author.

Full rationale, risks, and the migration record: the skill installation topology established in August 2026.

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

Legend: **Official** | **Substitute** | **MCP** | **In hub** | **Skip**

> **Since 2026-08-06** there is no per-skill wiring for Agy. `~/.gemini/config/skills` is a whole-directory symlink to the hub, so anything in `~/.claude/skills` is already there. Rows marked **In hub** need no action.

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
| elements-of-style | **Skip** — plugin-provided on Claude Code, not in the hub |
| graphify | **In hub** — no longer a separate `~/.gemini/config/skills/graphify` copy |
| briefing, capture-meeting, externalize-deliverable, learn, schedule-resume | **In hub** — copied in by [`sync-skills.sh`](../skills/sync-skills.sh) from `agentic-toolkit/skills/`, reached through the spoke symlink |
| penmark-comments | **In hub** — same path as the other authored skills. Canonical source is `agentic-toolkit/skills/penmark-comments`; the hub copy is no longer a live symlink into the repo, so edits need a sync run. See the [integration guide](guide-penmark-agent-integration.md) for validation and the deferred cross-harness audit. |
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

The repeatable test runner is **`@playwright/test`**. Microsoft also publishes [`@playwright/cli`](https://github.com/microsoft/playwright-cli) for agent-driven browser sessions; these are distinct interfaces, checked 2026-09-22. MCP idle cost is harness-dependent: Claude Code can defer tool schemas (~names until first use), so "skip the MCP to save context" only holds on eager-loading harnesses. Judging *looks* needs screenshots + vision either way — the accessibility snapshot shows structure, not aesthetics. Follow the [shared smoke procedure](guide-browser-automation-mcp-vs-cli.md#shared-smoke-procedure); configuration listings alone do not establish parity.

## Third-party routers (optional)

Not plugins — sit **under** or **beside** the harness:

- **llm-router** — prompt classification + hooks (Gemini CLI documented; verify Agy)
- **BrokeLLM** — slot lanes (sonnet/opus/haiku) + quota-aware harness mode
- **lite-harness** — unified API across claude-code / codex (no Agy yet)

Use when you want **dynamic** per-prompt routing; use **reference-workflow** `modelRouting` for **orchestrator-level** rules.

## Symlink rules of thumb

**Skills are no longer symlinked per-skill.** Since 2026-08-06 the direction is the reverse of what this section used to say: `~/.claude/skills` is the hub holding real directories, and each harness's skill directory is a whole-directory symlink *into* it. Nothing links out of the hub. Run [`../skills/sync-skills.sh`](../skills/sync-skills.sh) to copy authored skills in and repair the spokes; it is independent of the `find-skills` tool.

**Do symlink:** instruction files; whole harness skill directories pointing at the hub.

**Do not symlink:** full plugin directories from Cursor cache (hash paths break); MCP config; Superpowers twice; anything *out of* the hub into another location, which reintroduces the drift the hub exists to prevent. Vendor installers that fan out byte-identical copies per harness (`kimi-webbridge` did this) now only need the hub copy, since every harness resolves there.

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
