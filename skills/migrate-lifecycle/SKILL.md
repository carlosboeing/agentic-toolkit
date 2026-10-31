---
name: migrate-lifecycle
description: Migrate lifecycle documentation conventions in one project or an explicitly selected batch. Use for requested lifecycle folder, reference and frontmatter migrations, not ordinary phase work or automatic reorganization.
argument-hint: "[project-path | selected-project-list] [preview | apply]"
---

# Migrate lifecycle documentation

Make the migration repeatable. Use judgment to select destinations; use scripts to execute a checked mapping and verify preservation. This is adoption tooling, not a lifecycle phase. Do not redesign a project, rewrite its decisions, or manufacture missing phases.

## Select projects

Accept one explicit project path or a list. For “all projects,” obtain the search roots if unknown, discover repositories beneath them, and show the selected list before applying changes. Exclude linked directories, vendored repositories, archives and registered worktrees from automatic selection. A nested private working-memory repository belongs to its parent project but remains an independent Git target. Deduplicate repositories by their resolved paths.

Run serially. A request may authorize a whole named batch; do not ask again at each project when that scope is clear. Without apply authority, preview only. Installation, commits, pushes, PRs and merges follow the actual request, independently of migration authorization.

Find the toolkit checkout and read its [migration runbook](../../guides/guide-lifecycle-migration.md). Installed skills may lack the checkout-relative guide and root scripts. In that case locate the source checkout through existing configuration or ask for its path; do not download or install anything silently.

## Inspect and map

Read each project's instructions, Project Map, current conventions and installed validators. Inspect Git state, worktrees and evidence of concurrent writers. Record the exact source revision, selected working-memory root and the chosen branch/worktree. Use the project's workspace rules before changing branch state.

Inventory files, modes, links, assets and existing reference failures. Preserve uncommitted work; a dirty or diverged migration target is blocked until reconciled. Other independent targets may continue.

Propose an explicit file mapping. Folder numbers do not establish document meaning. Use type and content to separate requirements, technical designs, reviews, retrospectives and evergreen material. Raise consequential ambiguity; do not guess approval, status or product scope. Keep original types except the supported `discovery` to `research` alias. Move attachments with their owner only when exclusive; retain shared evidence with repaired links. Preserve frozen transcripts, historical paths and review provenance.

Build only the required reference edits and project-instruction changes. Avoid blind repository-wide replacement. Classify live navigation separately from historical examples. For each declared working-memory root, create all seven numbered lifecycle folders, adding `.gitkeep` to empty folders. Their presence requires no phase or artifact. Nested lesson and asset folders remain on demand. Do not create lifecycle folders in a public tree whose working memory belongs elsewhere.

## Rehearse, apply and recover

Use `scripts/migrate-lifecycle.py --manifest <manifest.json>` from the toolkit checkout. The runbook defines the manifest. Put each Git repository in its own entry with its full source commit ID, optional repository-relative working-memory root, exact file moves and counted literal replacements. Preview returns the complete patch and target tree per project. Keep manifests and reports outside migration targets and route private content appropriately. Do not invent unsupported flags.

After apply authority and installed compatibility are established, repeat with `--apply`. This stages the rehearsed patch but does not commit. It handles only listed tracked files; do not assume ignored evidence moved. Supported Markdown link regressions are checked, but bare-text references and metadata relationships still need the integrated comparison. Inspect each result even when the batch exits nonzero; blocked entries do not stop independent projects. A rerun recognizes the exact target tree; source drift needs reconciliation.

Rehearse deterministic transformations against the fixed source in a disposable copy. Include metadata normalization through the existing frontmatter CLI; deploy compatible validators before canonical fields become active. Keep original creation dates and explicit update values. Backfill missing update dates from recorded history before mechanical edits; missing history or conflicting values need resolution.

Present the exact proposed changes and unresolved cases. The reviewed mapping and recorded source revision define apply scope. Source changes invalidate that preview; refresh it rather than silently expanding it.

Before live application, persist intent and completion detection in the project's existing record. Verify source state again. Apply only the prepared changes. On interruption inspect Git, the completion record and actual files before retrying. Never label a partial result complete.

Verify the complete integrated result: all inventoried files accounted for, expected destinations, preserved content and provenance apart from authorized reference edits, unchanged frozen evidence and modes, no newly broken references, compatible active validation and a no-op rerun. Keep original failures separate from migration-caused failures. A passing diff check alone does not establish preservation.

Commit and publish only when authorized. Record actual effect SHAs before ticking durable progress in a following commit. Keep public and private commits separate. Stop affected work on a conflicting writer or unexplained partial effect.

## Report

Report each selected project as previewed, applied and verified, already complete, or blocked with its reason. Identify commits and publication state separately. Include the next recovery step for incomplete projects. Do not claim model or cross-harness reliability from mechanical checks.

Use any capable harness and a budget model for routine execution. Escalate ambiguous classification or unexpected failures; do not change verification requirements with model choice. Do not spawn parallel workers unless separately authorized.
