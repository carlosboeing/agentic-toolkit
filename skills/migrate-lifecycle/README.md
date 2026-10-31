# Lifecycle migration

An explicitly requested migration entry point for one project or a selected batch. It separates project-specific classification from deterministic changes and preservation checks.

Use `/migrate-lifecycle <project-path>` to inspect and preview. A natural-language request to migrate named projects also supplies scope. “All projects” first resolves search roots and a concrete repository list; it never means scan the whole computer without bounds.

Read the [runbook](../../guides/guide-lifecycle-migration.md) for the procedure, single/batch runner, existing frontmatter command and migration evidence. The skill requires the toolkit source checkout for root scripts. It does not install itself, select a provider, or authorize publication.

This is adoption tooling and may be retired after the selected projects are migrated. It does not add a phase or mandatory documents to ordinary development.
