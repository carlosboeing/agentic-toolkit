---
title: "Trimming Claude Code startup context"
type: guide
scope: [context-window, tokens, mcp, connectors, plugins, harness-config]
updated: 2026-07-08
related:
  - reference/reference-claude-code-context-costs.md
  - templates/lean-claude-settings/README.md
  - docs/1-discovery/2026-07-08-startup-context-token-breakdown-analysis.md
---

# Trimming Claude Code startup context

A fresh Claude Code session can open at ~75% context remaining before you type anything — a heavily-connected environment measured **~232k tokens of fixed startup** on the 1M window. This guide is the durable recipe that took that to **~70k (~93% remaining)** without losing any tool used in coding sessions. See the [cost reference](../reference/reference-claude-code-context-costs.md) for the per-server numbers this guide acts on.

## The one thing that matters

**MCP tool schemas are ~95% of the reducible startup cost** (173.6k of 232k in the measured case). Prose — CLAUDE.md, memory files — is under 4% combined; optimizing it is theatre. Attack MCP tools, ignore the rest.

Within MCP tools, **claude.ai connectors dominate** (~156k across Canva, Notion, Slack, Google Workspace, travel, Vercel, …), not plugins. Disabling `octo` + finance plugins reclaims only ~13k; the connectors are the prize.

## Step 0 — measure first

Change nothing until you can measure. Two tools:

- **`/context`** (TUI) — authoritative per-bucket + per-tool split. Run before and after every change.
- **Turn-1 `usage`** (scriptable) — see the [reference's measure loop](../reference/reference-claude-code-context-costs.md#measure-loop) for the one-liner.

**Golden rule:** reclaim is realized on the *next* session. Always **change → restart → `/context`**. Nothing is reclaimed until the meter confirms it.

## The three levers (and their granularity)

| Lever | Controls | Granularity | Versioned? |
|---|---|---|---|
| `disableClaudeAiConnectors: true` (settings.json) | all claude.ai connectors | **all-or-nothing** | ✅ |
| `enabledPlugins: {"x@mkt": false}` (settings.json) | one plugin's MCP + skills + agents | per-plugin | ✅ |
| `claude mcp add …` (self-config MCP in `~/.claude.json`) | one server | per-server; **survives `disableClaudeAiConnectors`** | ✅ |
| `/chrome` → "Enabled by default: No" | Claude-in-Chrome extension | on/off | menu toggle (reliable); `--no-chrome` is per-session only |

Two facts make the recipe work:
- Disabling connectors inside Claude Code does **not** touch the claude.ai web/desktop apps — those are separate account toggles. Lean Claude Code costs you nothing there.
- Connectors have **no per-connector file lever** — you can't durably keep *just* Notion. To keep one integration while cutting the rest, **self-host its MCP** (see Fathom below).

## The recipe: a global lean baseline

Set it once at user scope (`~/.claude/settings.json`); every project inherits it. Per-project `.claude/settings.json` is for exceptions only.

### 1. Self-host the integrations you actually use in code — FIRST

Do this **before** disabling connectors, so nothing breaks. Worked example — Fathom (needed by a `/capture-meeting` skill):

```bash
claude mcp add fathom -- npx mcp-remote@latest https://api.fathom.ai/mcp
```

Complete the OAuth in your browser, then verify: `/mcp` shows a `fathom` self-config server; call one tool (e.g. `get_identity`) to confirm it's authenticated. This is the *same* official backend the claude.ai Fathom connector proxied — same tools — but as a self-config stdio server it survives the connector flag. (Pin `mcp-remote@<version>` instead of `@latest` if you want to freeze the bridge.)

The pattern generalizes: any connector you need in code (Vercel, Notion, …) → self-host a lean MCP for it rather than keeping the heavy connector.

### 2. Disable all connectors

```json
// ~/.claude/settings.json
"disableClaudeAiConnectors": true
```

Restart → `/context` → confirm no `mcp__claude_ai_*` remain and your self-config server(s) survive.

### 3. Disable plugins you don't use

```json
// ~/.claude/settings.json → enabledPlugins
"financial-analysis@claude-for-financial-services": false,
"pitch-agent@claude-for-financial-services": false
// … keep the ones you use
```

Disabling (not uninstalling) reclaims 100% of a plugin's context — MCP, skills, and agents — and re-enabling is a one-line flip. There is no token benefit to uninstalling.

### 4. Drop redundant integrations

If two stacks cover the same ground, keep the cheaper one. Example: `claude-in-chrome` (~10k) overlaps with `superpowers-chrome` (~1.3k, drives an existing Chrome via CDP) and Playwright (~6k, fresh-browser automation). Disable it persistently via the `/chrome` menu → set **"Enabled by default: No"**, then summon it on demand with `claude --chrome` when you actually need your real logged-in browser.

> The reliable lever is the `/chrome` menu toggle. The `claudeInChromeDefaultEnabled` / `settings.json` keys are ignored (Claude Code issues [#26204](https://github.com/anthropics/claude-code/issues/26204), [#35825](https://github.com/anthropics/claude-code/issues/35825)), and `--no-chrome` is per-session only. This matches Anthropic's own guidance — enabling Chrome by default loads its tools into every session, so keep it off and use `--chrome` when needed.

## Reversibility

| Change | Undo |
|---|---|
| `disableClaudeAiConnectors: true` | delete the line / set `false` (user or a project scope) |
| plugin `false` | set `true` / delete the key |
| self-config MCP | `claude mcp remove <name>` |
| Claude-in-Chrome off (`/chrome` → Enabled by default: No) | `/chrome` → Enabled by default: Yes, or `claude --chrome` on demand |

## Measured result

| Stage | Fixed startup | Status line |
|---|---:|---:|
| Baseline | ~232k | ~75% remaining |
| + finance plugins off | ~226k | — |
| + connectors off (Fathom self-hosted) | ~84k | ~91% |
| + claude-in-chrome dropped | ~70k | ~93% |

## Per-project overrides

The global baseline makes every project lean. For a project that genuinely needs connectors back, opt out in its own `.claude/settings.json` with `"disableClaudeAiConnectors": false` — but note that restores **all** connectors (no per-connector file lever), so prefer self-hosting the one you need. See the [lean-settings template](../templates/lean-claude-settings/README.md).
