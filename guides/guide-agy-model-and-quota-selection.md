---
title: Antigravity model and quota selection
type: guide
scope: [antigravity, model-routing, quota]
last_reviewed: 2026-06-14
related:
  - guide-harness-plugin-parity.md
  - reference/reference-harness-capability-map.md
---

# Antigravity model and quota selection

Practical defaults for `agy` when running long autonomous sessions. **Not** platform-enforced routing — apply manually or via project rules / orchestrator config.

## Two independent quota pools

Antigravity tracks **separate** limits for:

1. **Gemini** (Flash, Pro, …)
2. **Claude + GPT** (Sonnet, Opus, …)

Weekly and 5-hour windows apply per pool. Exhausting Gemini does **not** block Claude/GPT, and vice versa.

Check before long runs: **Models & Quota** in the Agy UI (or equivalent in CLI session).

## Model roles (2026-06-14)

| Model | Pool | Use when |
|-------|------|----------|
| **Gemini 3 Flash (High)** | Gemini | Volume, exploration, docs, low-risk edits |
| **Gemini 3 Pro (High)** | Gemini | Stuck on Gemini; need more reasoning in same pool |
| **Claude Sonnet 4.6 (Thinking)** | Claude | Default **implementation** — code, tests, integration |
| **Claude Opus 4.6 (Thinking High)** | Claude | Hard integration, cross-layer bugs, architecture |
| **GPT 5.3 Codex (Medium / High)** | GPT | Optional; compare to Sonnet on your tasks |

**Thinking** variants: better for multi-step coding; **High** = more reasoning budget (slower, fewer turns left).

## Session strategy

1. **At session start:** read quota; if Gemini weekly is low (e.g. &lt;15%), plan Claude pool for serious work.
2. **Default coding:** Sonnet (Claude pool) — matches Penmark v0.5 “finish the run” when Gemini was ~9% left.
3. **Burn Gemini when healthy:** Flash for research, comments, doc passes.
4. **Escalate:** Pro (Gemini) → still stuck → Sonnet → Opus for R16-style integration.
5. **Persist choice:** `/model` in Agy applies to the session until changed.

## What Agy does not do

- Auto-switch model by file path or task type
- Read your orchestrator’s `modelRouting` JSON
- Share quota with Cursor Pro or Claude Code Max

For **rule-based** routing across harnesses, use **reference-workflow** (`modelRouting` + builder agents) or optional **llm-router** / **BrokeLLM** at the prompt layer.

## Optional project rule file

For soft hints in Agy (not enforced), add `.agents/rules/model-routing.md`:

```markdown
# Model routing (session hints)

- Default implementation: Claude Sonnet 4.6 (Thinking)
- Escalate to Opus: cross-layer integration, repeated test failures after 2 fix cycles
- Use Gemini Flash only when Gemini weekly quota > 20%
- Before R16-style work: confirm Claude pool headroom
```

## Google AI Pro vs agent quota

**Google AI Pro** (5TB storage, etc.) is a **consumer subscription** — not the same meter as **Models & Quota** inside Agy for agent turns. Do not assume “Pro = unlimited agents.”

## See also

- [Harness plugin parity](guide-harness-plugin-parity.md)
- [Capability map](../reference/reference-harness-capability-map.md)
- Discovery: [2026-06-14 harness parity research](../docs/1-discovery/2026-06-14-harness-parity-model-routing-research.md)
