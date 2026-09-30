---
date: 2026-09-30
title: Agent memory options and observer costs
type: reference
authors:
  - "Carlos Boeing"
  - "gpt-6 (codex)"
scope: [agent-memory, claude-mem, engram, basic-memory, mcp, observer-models]
related:
  - ../guides/guide-agent-memory-selection.md
  - ../guides/guide-claude-mem-setup.md
  - ../guides/guide-ai-model-and-effort-routing.md
---

# Agent memory options and observer costs

This reference records provider documentation and source-code findings checked on 2026-09-30. It recommends a low-cost observer trial for existing claude-mem users and local Engram or Basic Memory trials for users who prefer selective capture. It is for comparing options; no replacement system or observer candidate was installed or benchmarked during this review.

## Recommendation and its limits

Keep a working claude-mem store while testing MiMo-V2.6-Flash as a lower-cost observer, with MiMo-V2.6-Pro as a stronger candidate if Flash loses useful facts. General model benchmarks do not establish their observation-extraction quality. Choose through a same-input comparison, as described in the [selection guide](../guides/guide-agent-memory-selection.md).

For a replacement, local Engram is the first candidate for reducing runtime dependencies. Basic Memory is the alternative for readable Markdown ownership. Neither is established here as more reliable than claude-mem, and removing a dedicated observer changes the capture behavior.

## Memory systems

| System | Storage and runtime | Capture behavior | Main qualification |
|---|---|---|---|
| [claude-mem](https://github.com/thedotmack/claude-mem) | Local SQLite worker, Node/Bun tooling, optional semantic-search dependencies | A separate model extracts observations and summaries from captured activity | Retrieval can work while observer capacity is exhausted; automatic capture depends on the harness integration |
| [Engram](https://github.com/Gentleman-Programming/engram) | Local Go binary and SQLite FTS5; optional cloud features | Agent-authored observations and summaries; optional capture parses structured agent output | The local core avoids a dedicated observer; the full project includes optional services and integrations |
| [Basic Memory](https://github.com/basicmachines-co/basic-memory) | Markdown files and a SQLite index, Python runtime, optional semantic retrieval | Agent-authored notes plus harness-specific checkpoints | Readable source files are a portability advantage; checkpoints are not continuous semantic extraction |
| [MCP Memory Service](https://github.com/doobidoo/mcp-memory-service) | Python service, SQLite, local ONNX embeddings and integration hooks | Automatic Claude Code and OpenCode integrations are documented | Equivalent automatic capture in Codex was not verified; the Claude plugin is experimental |

Engram's latest stable release checked was v2.2.1. Its published self-tests cover isolated concurrent writes, and recent releases address SQLite write-lock and WAL defects and reject detected remote filesystems for WAL operation. These mechanisms support a trial; they do not establish a comparative reliability result. Sources: [releases](https://github.com/Gentleman-Programming/engram/releases), [self-tests](https://github.com/Gentleman-Programming/engram/blob/main/docs/SELF-TESTING.md).

Basic Memory's Claude compaction checkpoint deterministically extracts the opening request and recent user messages without an LLM call. Its Codex integration asks the resumed coding agent to author a checkpoint after compaction. Lifecycle metadata capture is a separate feature. Source: [hook implementation](https://github.com/basicmachines-co/basic-memory/blob/main/src/basic_memory/cli/commands/hook.py).

MCP Memory Service documents automatic Claude and OpenCode integrations, but its recommended Claude plugin is experimental and describes failed-write cases. Generic MCP access is not proof of automatic Codex capture. Sources: [plugin documentation](https://github.com/doobidoo/mcp-memory-service/blob/main/claude-hooks/PLUGIN.md), [OpenCode integration](https://github.com/doobidoo/mcp-memory-service/blob/main/opencode/README.md), [integrations](https://github.com/doobidoo/mcp-memory-service/blob/main/docs/integrations.md).

## Other options considered

| Option | Why it is not the first replacement candidate |
|---|---|
| [Official MCP memory server](https://github.com/modelcontextprotocol/servers/tree/main/src/memory) | A small reference implementation. Source shows atomic file replacement and an in-process mutation queue, but no cross-process lock was identified. Do not assume simultaneous processes can safely share the same memory file. |
| [OpenMemory](https://github.com/mem0ai/openmemory) | The current repository describes a beta session-porting CLI/TUI and lists autosync as forthcoming. Do not confuse it with earlier OpenMemory MCP deployments. |
| [Graphiti](https://github.com/getzep/graphiti) | Adds graph storage and LLM ingestion. It does not fit a goal of reducing the components needed for coding-session memory. |
| Markdown and Git | Suitable for deliberate notes and authoritative decisions, but not a passive session extractor. Searching existing project documents is a different requirement from creating new session memories. |

## Observer candidates and API rates

Prices below were checked on 2026-09-30. They are USD per million tokens and pair each backend's input and output rates. The example uses 1,000,000 input tokens and 100,000 output tokens; it is not a monthly estimate or a measured session cost.

| Model and backend | Input | Output | Example cost | Source |
|---|---:|---:|---:|---|
| MiMo-V2.6-Flash, OpenRouter/DeepInfra listing | $0.08 | $0.28 | $0.108 | [Model and providers](https://openrouter.ai/xiaomi/mimo-v2.6-flash) |
| MiMo-V2.6-Pro, OpenRouter/DeepInfra listing | $0.43 | $0.87 | $0.517 | [Model and providers](https://openrouter.ai/xiaomi/mimo-v2.6-pro) |
| Gemini 3.1 Flash-Lite, Google paid text API | $0.25 | $1.50 | $0.400 | [Google pricing](https://ai.google.dev/gemini-api/docs/pricing#gemini-3.1-flash-lite) |

OpenRouter's route can change the bill. Its Flash headline price checked here was $0.04 input and $1.28 output on a different backend, while the Xiaomi listing was $0.14 input and $0.28 output. The cheapest input rate and cheapest output rate cannot be combined as though they were one offer. Confirm the selected backend and billed usage before relying on a rate.

MiMo-V2.6-Flash is the cheapest paid candidate in this shortlist under the stated example. Pro is the stronger candidate to test when Flash misses facts. No observation-specific benchmark proves either model's adequacy, and this comparison does not claim to cover every available model.

The claude-mem 13.28.0 native Gemini adapter checked for this review accepts `gemini-3.1-flash-lite` and excludes `gemini-2.5-flash-lite`. Its OpenRouter integration accepts model identifiers separately. Verify the installed adapter's model validation before changing providers; current upstream documentation may describe a newer version. Sources: [Gemini provider](https://docs.claude-mem.ai/usage/gemini-provider), [OpenRouter provider](https://docs.claude-mem.ai/usage/openrouter-provider).

Google offers a Gemini 3.1 Flash-Lite free tier with its own limits. Its price table lists free-tier data as used for product improvement and paid-tier data as not used for that purpose. Provider approval and data handling are part of the choice, not just the token rate. Source: [Google pricing](https://ai.google.dev/gemini-api/docs/pricing#gemini-3.1-flash-lite).

## Evidence needed before adoption

No new provider, paid inference, replacement installation or migration was run for this comparison. Before adoption, verify observer output against known facts, capture from every required harness, recall from a fresh session, simultaneous writes, and restoration into an empty store. Record the actual route, token volume, retries and operating dependencies.

Refresh this reference when a model, backend rate, adapter version or integration changes. Preserve the recorded date and do not label a documentation review as an end-to-end installation test.
