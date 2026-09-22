# Reference

These files preserve dated product facts, configuration inventories, performance measurements, and repository standards. Read each file's evidence date before using volatile model, quota, or price data.

## Catalog

| Reference | What it covers |
|---|---|
| [`reference-cross-harness-models.md`](reference-cross-harness-models.md) | Model capabilities, routing aliases, API rates, subscription limits, and deployment economics across the supported harnesses. |
| [`reference-harness-capability-map.md`](reference-harness-capability-map.md) | Feature-by-feature capability support map across developer agent harnesses. |
| [`reference-claude-code-plugins.md`](reference-claude-code-plugins.md) | Snapshot of installed plugins and marketplaces configured on Claude Code. |
| [`reference-rtk-token-savings.md`](reference-rtk-token-savings.md) | Dated tool-reported RTK measurements, with counting and billing limitations. |
| [`reference-headroom-savings.md`](reference-headroom-savings.md) | Historical installation layout and compression measurements for the retired Headroom proxy. |
| [`reference-headroom-alternatives.md`](reference-headroom-alternatives.md) | Historical Headroom alternatives comparison; unsupported rows are marked unverified. |
| [`reference-claude-code-context-costs.md`](reference-claude-code-context-costs.md) | Per-bucket and per-server startup token costs from `/context`, with the control lever and lean replacement for each connector/plugin, plus the measure loop. |
| [`reference-third-party-skills.md`](reference-third-party-skills.md) | Source and rebuild command for every skill in the `~/.claude/skills` hub this repo does not author. External skills are not bundled in this repository. |
| [`reference-oss-standards.md`](reference-oss-standards.md) | OSS house standard checklist for any `carlosboeing/*` public repo - health files, pinned workflows, `required` gate, `dependabot`, rulesets, no personal email. |
| [`reference-build-and-release-standards.md`](reference-build-and-release-standards.md) | Build and release house standard for any `carlosboeing/*` repo that ships a binary - marked local versions, install entry points, one build script, the agreement gate. |

## Conventions

- Filenames are `reference-<topic>.md`. The prefix ensures the file remains self-describing if emailed, gisted, or copied elsewhere.
- Start each reference document with YAML frontmatter containing its title, `type: reference`, scope, review date, authors, and relevant related links.
- State the evidence date beside volatile facts and link the primary source.
- Keep historical measurements intact. Update a current-value table only after checking the cited source.
