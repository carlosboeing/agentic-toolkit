---
title: Antigravity model and quota selection
type: guide
authors:
  - "Carlos Boeing"
  - "gpt-5.6-sol (codex)"
scope: [antigravity, model-selection, quota, sessions]
last_reviewed: 2026-08-02
related:
  - guide-ai-model-and-effort-routing.md
  - ../reference/reference-cross-harness-models.md
  - guide-harness-plugin-parity.md
  - ../reference/reference-harness-capability-map.md
---

# Antigravity model and quota selection

Model choices below record the 2026-08-02 comparison. On 2026-09-22, [Google's model list](https://antigravity.google/docs/models) includes Gemini 3.8 Flash and 3.7 Flash as well as 3.6 Flash. The table is not the complete current picker. Verify availability and quota in your account before applying the historical routing examples.

This is the Antigravity operating supplement. Use the [AI model and effort routing guide](guide-ai-model-and-effort-routing.md) to choose a model for a task and the [cross-harness reference](../reference/reference-cross-harness-models.md) for benchmarks, prices, and comparisons.

## Recorded picker

The August comparison used these models and effort choices. Check the live picker before a long session because availability can change. [Antigravity models](https://antigravity.google/docs/models)

| Model | Effort | Use inside Antigravity |
|---|---|---|
| Gemini 3.6 Flash | low, medium, high | Fast research, docs, browser work, visual iteration, and light coding |
| Gemini 3.5 Flash | low, medium, high | Compatibility or availability fallback |
| Gemini 3.1 Pro | low, high | Harder reasoning, long-context synthesis, and consequential visual judgment |
| Claude Sonnet 4.6 Thinking | Thinking | Implementation and review when the Claude/GPT pool has headroom |
| Claude Opus 4.6 Thinking | Thinking | Difficult architecture or repair loops inside Agy |
| GPT-OSS 120B | medium | Bounded open-weight work and behavioral comparison |

Antigravity's effort labels are not equivalent to Claude Code, Codex, or Kimi effort. Pick the lowest level that fits the task: low for extraction, medium for routine work, high/Thinking for ambiguity and multi-step reasoning.

## Quota behavior

Google AI Pro receives higher Antigravity quota, refreshed every five hours until the weekly quota is reached. Google does not publish a stable absolute turn count; model, workload, capacity, and account state affect consumption. AI credits may provide overage where the account supports them. [Antigravity plans](https://antigravity.google/docs/plans)

Do not assume that Google AI Pro storage or consumer Gemini entitlements mean unlimited Antigravity agent use.

Check capacity with:

- `/usage` for the current session's usage view;
- `/quota` for quota status where available;
- the Antigravity UI's Models and Quota view.

The CLI commands are documented in [Antigravity usage commands](https://antigravity.google/docs/cli/commands/usage).

## Session workflow

1. Check quota before a long or autonomous run.
2. Use Gemini 3.6 Flash medium for collection and ordinary browser work.
3. Raise Flash to high for visual QA or moderately complex reasoning.
4. Move to Gemini 3.1 Pro high when Flash misses relationships, the visual judgment is consequential, or long-context synthesis is the task.
5. Use Sonnet 4.6 Thinking for implementation when its independent Agy capacity is more valuable than using native Claude Code.
6. Reserve Opus 4.6 Thinking for hard Agy-native repair or architecture. Native Claude Code exposes newer Claude models, so prefer it when model generation matters more than Agy's browser/autonomy/quota.
7. Start a fresh session when changing task class, when obsolete investigation dominates context, or when a completed phase no longer helps the next one.

## Operational fallbacks

| Situation | Action |
|---|---|
| Gemini five-hour capacity is tight | Move bounded collection to Codex Luna, Kimi K3-256k/K2.7, or an open-weight worker. |
| Weekly Agy capacity is tight | Keep Agy for work that needs its browser/visual/autonomous tools; move ordinary terminal coding to Codex, Claude Code, or Kimi. |
| Flash gives a weak result | Improve scope and evidence, then raise effort. Move to Pro only when the task is genuinely harder. |
| Agy's Claude model is too old for the task | Use native Claude Code with Sonnet 5 or Opus 5. |
| A long session becomes noisy | Save a compact state/evidence packet and start a fresh session instead of increasing effort. |
| The task needs a real logged-in browser | Use Kimi WebBridge and supervise any destructive or purchasing action. |

## What Antigravity does not decide for you

Antigravity does not know which of your other subscriptions has the cheapest adequate capacity. It also cannot infer business impact, privacy requirements, or whether a 1M context is actually necessary. Apply the cross-harness routing policy before choosing from this picker.

Do not keep a duplicated cross-provider ranking here. When a model, price, or benchmark changes, update the [canonical reference](../reference/reference-cross-harness-models.md); change this supplement only when Antigravity's picker or quota/session behavior changes.
