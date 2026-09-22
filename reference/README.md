# Reference

These files preserve dated product facts, configuration inventories, performance measurements, and repository standards. Read each file's evidence date before using volatile model, quota, or price data.

## Catalog

| Reference | What it covers |
|---|---|
| [`reference-harness-capability-map.md`](reference-harness-capability-map.md) | Feature-by-feature capability support map across developer agent harnesses. |
| [`reference-oss-standards.md`](reference-oss-standards.md) | OSS house standard checklist for any `carlosboeing/*` public repo - health files, pinned workflows, `required` gate, `dependabot`, rulesets, no personal email. |
| [`reference-build-and-release-standards.md`](reference-build-and-release-standards.md) | Build and release house standard for any `carlosboeing/*` repo that ships a binary - marked local versions, install entry points, one build script, the agreement gate. |

## Conventions

- Filenames are `reference-<topic>.md`. The prefix ensures the file remains self-describing if emailed, gisted, or copied elsewhere.
- Start each reference document with YAML frontmatter containing its title, `type: reference`, scope, review date, authors, and relevant related links.
- State the evidence date beside volatile facts and link the primary source.
- Keep historical measurements intact. Update a current-value table only after checking the cited source.
