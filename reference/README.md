# Reference

Snapshots, inventories, and lookups for coding agent configurations and historical performance. Reference files capture the state of resources, capability mapping, or analytics metrics.

## Catalog

| Reference File | What it covers |
|---|---|
| [`reference-cross-harness-models.md`](reference-cross-harness-models.md) | Comparison of LLM models by capability tiers, routing aliases, and availability/quota across Claude Code, Cursor, Antigravity, and Kimi Code. |
| [`reference-harness-capability-map.md`](reference-harness-capability-map.md) | Feature-by-feature capability support map across developer agent harnesses. |
| [`reference-claude-code-plugins.md`](reference-claude-code-plugins.md) | Snapshot of installed plugins and marketplaces configured on Claude Code. |
| [`reference-rtk-token-savings.md`](reference-rtk-token-savings.md) | Performance metrics and command optimization strategies for RTK (Rust Token Killer) based on historical CLI runs. |
| [`reference-headroom-savings.md`](reference-headroom-savings.md) | Installation layout and context compression metrics for Headroom context optimization proxy. |
| [`reference-headroom-alternatives.md`](reference-headroom-alternatives.md) | Architectural comparison of Headroom alternatives including Kompact, LLMLingua-2, and Native Provider Caching. |
| [`reference-claude-code-context-costs.md`](reference-claude-code-context-costs.md) | Per-bucket and per-server startup token costs from `/context`, with the control lever and lean replacement for each connector/plugin, plus the measure loop. |

## Conventions

- Filenames are `reference-<topic>.md`. The prefix ensures the file remains self-describing if emailed, gisted, or copied elsewhere.
- Each reference document includes YAML frontmatter detailing title, type (`reference`), scope list, last reviewed date, and related guides or references.
