---
date: 2026-08-04
title: Remove the Headroom compression proxy from all harnesses
type: adr
status: approved
authors:
  - "Carlos Boeing"
  - "claude-opus-5 (claude-code)"
scope: [headroom, proxy, context-compression, harness-parity, claude-code, cursor]
related: []
---

# 0001: Remove the Headroom compression proxy from all harnesses

## Considered

- **Keep it, upgrade to current.** The install was on 0.25.0, 74 releases behind 0.33.0.
- **Keep it, patch the timeout locally.** One-line edit to the installed package.
- **Keep it, but route verbatim-critical work around it.** Disable per-session for document work, keep it for exploratory sessions.
- **Remove it entirely.** Uninstall, revert all managed config, go direct to the provider APIs.

## Picked

Remove it entirely, across every harness.

## Why

Three findings, in descending order of how much they settle the question.

**The stall bug is unfixed upstream and not configurable.** A five-hour plan-writing session on 2026-08-04 died five times with `API Error: Response stalled mid-stream`, each time exactly 300 or 301 seconds after the last streamed token. The cause is `request_timeout_seconds: int = 300` in `headroom/proxy/models.py`, wired into the httpx client as both the read and write timeout in `headroom/proxy/server.py`. When Opus 5 at `xhigh` effort composes a large document, it goes quiet for longer than five minutes and httpx kills the socket mid-stream. Both sides logged the same instant — Claude Code reported the stall, Headroom logged `Could not parse output_tokens from SSE` — and no `UPSTREAM_ERROR` was recorded on any of the five, so the provider API never failed. Checking 0.33.0 closed off the upgrade path: the default is still 300, still has no CLI flag and no env binding, 74 releases later. The sibling setting `connect_timeout_seconds` gets both a flag and an env var; this one gets neither.

**It silently corrupts reads that must be byte-exact.** The same session hit lossy compression repeatedly and said so: *"The decisions document came back compressed and lossy — words are dropped throughout."* The documented recovery path then failed outright — *"Hash expired. I'll read the file in smaller chunks so the compression layer doesn't kick in."* That is the mitigation our own instructions prescribe for this exact situation, and it did not hold. The session burned 39 Read calls chipping away at small line ranges to defeat the compressor. A second session reproduced it live: a prompt file came back as *"Rather keep merging new design into stale plan, launch pass gets fresh plan written approved decisions"* where the bytes on disk read *"Rather than keep merging a new design into a stale plan, the launch pass gets a fresh plan written from the approved decisions."* Articles, prepositions and auxiliaries stripped. The task's stated quality bar was that every copy string be byte-identical to its source document, which a lossy read layer cannot satisfy.

**The token economics invert on cached workloads.** Measured savings were roughly 10,000 to 11,000 tokens per request, about 8%. But the proxy rewrites the request body every turn — logged as `body_mutated=true` — and injects five memory tools via sticky replay. Tool definitions sit at the front of the cached prefix, so mutating them breaks prompt caching. Two of four consecutive measured turns had broken caches, at 0% and 29% hit rate, each re-writing 162,000 to 225,000 tokens. On extended one-hour cache TTL, where writes are the expensive operation, destroying a 225,000-token cached prefix to save 11,000 tokens is a large net loss.

The third point is workload-specific and would not on its own justify removal — on long exploratory sessions where the cache survives, 8% is real. The first two are not workload-specific. An unfixable five-minute ceiling on silent generation, combined with silent corruption of file reads whose recovery mechanism expires, is disqualifying for document work regardless of the savings.

## What removal touched

Headroom's own teardown verbs did most of it. `headroom install remove --profile default` reverted the managed config, and the package was uninstalled afterwards.

| Item | Location |
|---|---|
| LaunchAgent (`KeepAlive: true`, so it respawned on plain kill) | `~/Library/LaunchAgents/com.headroom.default.plist` |
| Claude Code env override | `~/.claude/settings.json` → `env.ANTHROPIC_BASE_URL` |
| Shell env block (both vars, all harnesses) | `~/.zshrc`, `~/.profile` |
| MCP server registration | `~/.claude.json` → global `mcpServers.headroom` |
| Package | `uv tool uninstall headroom-ai` |

Two details worth keeping. The deploy manifest targeted both `claude` and `cursor`, and the shell block exported `ANTHROPIC_BASE_URL` and `OPENAI_BASE_URL` globally — so every CLI harness launched from that shell was routed through the proxy, not just Claude Code. And Headroom ships no `mcp uninstall` counterpart to `headroom mcp install`, so the MCP registration had to be removed by hand with `claude mcp remove headroom -s user`.

## Consequences

Claude Code now talks directly to the provider API with its own 600-second timeout — double the ceiling that was killing sessions, though still a ceiling. For deliverables large enough to risk ten minutes of silent composition, the durable fix is structural: write in sections rather than one monolithic pass, so tokens keep flowing.

RTK is unaffected and stays. It filters shell command output only, bypasses the native file-read tool entirely, and has near-zero effect on prose. The compression-layer warning in the global instructions still applies to it, at much lower stakes.

## Related

- The Headroom setup guide, retired by this decision, is no longer published.
