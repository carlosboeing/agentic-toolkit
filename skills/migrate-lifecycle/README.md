# Lifecycle migration

An explicitly requested migration entry point for one project or a selected batch. It separates project-specific classification from deterministic changes and preservation checks.

Use `/migrate-lifecycle <project-path>` to inspect and preview. A natural-language request to migrate named projects also supplies scope. “All projects” first resolves search roots and a concrete repository list; it never means scan the whole computer without bounds.

Read the [runbook](../../guides/guide-lifecycle-migration.md) for the procedure, single/batch runner, existing frontmatter command and migration evidence. The skill requires the toolkit source checkout for root scripts. It does not install itself, select a provider, or authorize publication.

Each preview checks where requirements are recorded. When requested, the agent derives an additional draft brief or PRD from existing brainstorms, designs and plans using the SDD requirements template. The original documents retain their content and authority; structural folder, metadata and link repairs remain separate. The extraction identifies source revisions, maps requirements to evidence and distinguishes explicit decisions from inferences and open questions. Existing sufficient requirements records are reused.

For example: "Preview this project's lifecycle migration, including an additive requirements extraction from its design and plan. Keep the original documents intact." The preview includes the exact new document as well as the structural changes. The script handles structural migration; the agent prepares and verifies the additional document separately. See [requirements extraction and recovery](../../guides/guide-lifecycle-migration.md#assess-requirements-and-optionally-extract).

This is adoption tooling and may be retired after the selected projects are migrated. It does not add a phase or mandatory documents to ordinary development.
