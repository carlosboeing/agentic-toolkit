# Reference

Dated facts and standards: what each harness supports, and the repository standards the skills apply. Check a file's evidence date before relying on anything that changes often, such as product capabilities.

## Catalog

| Reference | What it covers |
|---|---|
| [`reference-harness-capability-map.md`](reference-harness-capability-map.md) | What each AI coding harness supports, feature by feature |
| [`reference-oss-standards.md`](reference-oss-standards.md) | The house standard for open-source repositories: health files, pinned workflows, the `required` check, Dependabot, branch protection and no personal email |
| [`reference-build-and-release-standards.md`](reference-build-and-release-standards.md) | The house standard for repositories that ship a binary: version strings, install entry points, one build script and the release check |

The two house standards are the maintainer's own, written for `carlosboeing/*` repositories. Each one explains how to adapt it.

## Writing a reference

- Name the file `reference-<topic>.md`, so a copied file is still recognizable outside this repository.
- Start with YAML frontmatter: `title`, `type: reference`, `scope`, the review date, `authors`, and any `related` links.
- Put the evidence date next to any fact that changes often, and link its source.
- Keep historical measurements as they were recorded. Update a current value only after checking its source.
- Follow the [documentation standard](../CONTRIBUTING.md#documentation-standard).
