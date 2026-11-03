---
name: migrate-lifecycle
description: Migrate lifecycle documentation conventions in one project or an explicitly selected batch, including optional requirements extraction. Use for requested lifecycle migrations, not ordinary phase work or automatic reorganization.
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

Inspect discovery consumers before moving records. Include declared roots and any existing QMD collection patterns in the preview: legacy-only globs can omit the new paths. Preserve collection roots, exclusions and visibility; configuration writes require their actual authority. Reindex only after authorized updates and verify the intended records can be found. Do not register transient worktrees or add models, embeddings, daemons or MCP services.

Propose an explicit file mapping. Folder numbers do not establish document meaning. Use type and content to separate requirements, technical designs, reviews, retrospectives and evergreen material. Raise consequential ambiguity; do not guess approval, status or product scope. Keep original types except the supported `discovery` to `research` alias. Move attachments with their owner only when exclusive; retain shared evidence with repaired links. Preserve frozen transcripts, historical paths and review provenance.

Build only the required reference edits and project-instruction changes. Avoid blind repository-wide replacement. Classify live navigation separately from historical examples. For each declared working-memory root, create all seven numbered lifecycle folders, adding `.gitkeep` to empty folders. Their presence requires no phase or artifact. Nested lesson and asset folders remain on demand. Do not create lifecycle folders in a public tree whose working memory belongs elsewhere.

## Assess requirements and optionally extract

Each preview identifies the existing requirements owner and whether a separate brief would help. Reuse a sufficient requirements record. When requirements are embedded in brainstorms, designs or plans, report the candidate sources; extract only within the requested scope. Empty folders and historical work do not require retrospective PRDs.

For requested extraction, read the [requirements contract](../start-requirements/references/requirements-contract.md) and [SDD requirements template](../start-requirements/references/requirements-template.md), honoring project overrides. Create an additional document in the declared `2-requirements/` folder. Keep the original documents, embedded requirements, approval text and task history intact. Extraction adds no edits to source documents; separately authorized structural moves, metadata normalization and reference repairs still apply. Follow the owning project's public/private routing even when its application repository is public.

Identify every source by its original path at the fixed revision, section and migrated live path. Preserve existing requirement and acceptance IDs with their source context; disambiguate collisions between documents. Give extracted requirements readable acceptance criteria, including relevant failure cases and imposed constraints. Distinguish explicit source statements from inferred requirements, conflicting decisions and unresolved gaps. Inference is permitted when traceable to evidence; do not invent accepted scope, numerical targets or delivery claims. Create the new document with extraction-date `created` and `updated`, leaving original dates and attribution on the sources.

Start the extraction as `draft`, name its contributing authors and record its extraction date and source revisions. The original scope owner remains authoritative; the new document is a derived reference pending acceptance. It inherits neither approval nor `reviewed_by` nor shipped status. Do not copy source authors as contributors to the extraction. Conflicts block accepting the affected requirements, not an independently safe structural migration. Acceptance or a later transfer of authority follows the actual request and project rules; extraction alone does not grant it.

Include the complete additional document and a source-to-requirement coverage table in the preview, recording exclusions, inferences and conflicts. Rehearse its exact additive patch after the structural target in a disposable copy. The deterministic runner does not create PRDs. Save the structural and final target trees separately, and follow the runbook's recovery checks before applying or retrying either part.

## Rehearse, apply and recover

Use `scripts/migrate-lifecycle.py --manifest <manifest.json>` from the toolkit checkout. The runbook defines the manifest. Put each Git repository in its own entry with its full source commit ID, optional repository-relative working-memory root, exact file moves and counted literal replacements. Preview returns the complete patch and target tree per project. Keep manifests and reports outside migration targets and route private content appropriately. Do not invent unsupported flags.

After apply authority and installed compatibility are established, repeat with `--apply`. This stages the rehearsed patch but does not commit. It handles only listed tracked files; do not assume ignored evidence moved. Supported Markdown link regressions are checked, but bare-text references and metadata relationships still need the integrated comparison. Inspect each result even when the batch exits nonzero; blocked entries do not stop independent projects. A rerun recognizes the exact target tree; source drift needs reconciliation.

Rehearse deterministic transformations against the fixed source in a disposable copy. Include metadata normalization through the existing frontmatter CLI; deploy compatible validators before canonical fields become active. Keep original creation dates and explicit update values. Backfill missing update dates from recorded history before mechanical edits; missing history or conflicting values need resolution.

Present the exact proposed changes and unresolved cases. The reviewed mapping and recorded source revision define apply scope. Source changes invalidate that preview; refresh it rather than silently expanding it.

Before live application, persist intent and completion detection in the project's existing record. Verify source state again. Apply only the prepared changes. On interruption inspect Git, the completion record and actual files before retrying. Never label a partial result complete.

Verify the complete integrated result: all inventoried files accounted for, expected destinations, preserved source content and provenance apart from authorized structural metadata/reference edits, unchanged frozen evidence and modes, no newly broken references and compatible active validation. Verify the structural no-op before any extraction patch. For extraction, also compare source bodies against the structural target, check requirement coverage and confirm the recorded final tree before reporting completion. Keep original failures separate from migration-caused failures. A passing diff check alone does not establish preservation.

Commit and publish only when authorized. Record actual effect SHAs before ticking durable progress in a following commit. Keep public and private commits separate. Stop affected work on a conflicting writer or unexplained partial effect.

## Report

Report each selected project as previewed, applied and verified, already complete, or blocked with its reason. Identify commits and publication state separately. Include the next recovery step for incomplete projects. Do not claim model or cross-harness reliability from mechanical checks.

Report requirements separately as reused, extraction not requested, extraction unnecessary, drafted or blocked, with sources, remaining gaps and retained authority. A structurally migrated project can still have a draft extraction awaiting acceptance.

Use any capable harness and a budget model for routine execution. Escalate ambiguous classification or unexpected failures; do not change verification requirements with model choice. Do not spawn parallel workers unless separately authorized.
