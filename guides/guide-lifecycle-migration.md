# Migrate lifecycle documentation in existing projects

This runbook covers adoption in one project or an explicitly selected batch. It separates classification decisions from deterministic file and metadata changes. It is for an operator or coding agent using the toolkit checkout.

## Start with an explicit scope

Invoke `/migrate-lifecycle <project-path>` after the skill is installed, or ask an agent to follow this runbook for named projects. Preview is the default. To cover all projects, name the search roots and review the discovered repository list before applying changes.

Use the same procedure for one or many projects. Work serially and record each project's source revision, working-memory root, mapping, result and next recovery step. A blocked project need not block unrelated repositories. A batch is complete only when every selected project has a recorded disposition.

A nested private repository is a separate Git target. Migrate its working-memory records there and public instructions in their owning repository. Never combine them in one commit or put private source references in public tracking.

## Start in a fresh session

1. Open a coding harness in the target project's repository root. It needs local file access, a terminal, Git and Python 3. Use the model guidance at the end of this runbook.
2. Replace `<toolkit-checkout>` in the prompt with the absolute path to your toolkit source checkout. The source checkout supplies the runbook and scripts even when the skill is loaded from the shared hub.
3. Paste the preview prompt below. Skill invocation syntax differs across harnesses; the ordinary-language request and explicit source paths provide the same starting instructions.
4. Review the proposed mapping, unresolved classifications and verification results. The preview must leave target project files unchanged. If a dirty tree or incompatible validator blocks application, resolve that condition before proceeding.
5. Apply only after the preview is acceptable. Use the continuation prompt below in the same session, or provide the saved manifest and preview paths to a fresh session.

### Copyable preview prompt

Replace the path placeholder before pasting.

════ PROMPT STARTS BELOW THIS LINE ════

Use the migrate-lifecycle skill to prepare a migration preview for the project in the current directory.

Toolkit source checkout: `<toolkit-checkout>`.

Read the skill from that checkout at `skills/migrate-lifecycle/SKILL.md` and follow `guides/guide-lifecycle-migration.md`. If the harness has already loaded the installed skill, still use the checkout for the runbook and scripts.

For each selected project, read its instructions, Project Map, Git state and actual documentation structure. Include lifecycle folders, YAML frontmatter, live references and project instructions. Preserve product decisions, document bodies except approved reference repairs, original dates, review provenance, historical evidence, assets and existing uncommitted work. Identify ignored evidence that needs separate handling.

Identify the existing requirements owner and any useful extraction candidates. If requirements extraction is included in my request, preview additional draft requirements documents using the SDD template, with source revisions and coverage. Keep the original brainstorms, designs and plans intact apart from the structural migration. Distinguish explicit requirements from inferences, conflicts and gaps; retain the original scope owner's authority.

Work serially. Inspect and propose an explicit mapping; raise ambiguous classifications instead of guessing. Use the deterministic runner to rehearse against a fixed source revision in a disposable copy. Check installed validator compatibility. Keep the manifest and preview in an appropriate private location outside the target repository; ask for that location if none is established.

Show the proposed changes, verification results, blockers and unresolved decisions. Give me the saved manifest and preview paths so another session can resume.

Stop after the preview. Do not edit the selected projects, install validators, change global configuration, commit, push or open a PR.

════ PROMPT ENDS ABOVE THIS LINE ════

The delimiters are not part of the prompt.

### Select several projects or discover a bounded batch

For named projects, replace the preview prompt's first sentence with: "Use the migrate-lifecycle skill to prepare migration previews for these project roots: `<project-root-1>`, `<project-root-2>`." Keep the rest of the prompt. Each repository, including a private companion when present, gets its own manifest entry and result.

For all projects under a directory, replace that sentence with: "Discover candidate projects only beneath `<search-root>`. Show me the deduplicated repository list and exclusions, then wait for my selection before preparing previews." This first step discovers the scope. It does not authorize migration of every repository it finds. Once selected, preview serially; report blocked projects and continue independent ones.

To include requirements extraction, add: "For `<selected-projects>`, also infer or extract requirements from the selected brainstorms, designs and plans into additional draft documents under the declared requirements folder. Preserve the original documents and their authority; include the exact new documents and source coverage in the preview." This requests extraction previews, not acceptance of their requirements or live application.

### Continue from an accepted preview

Fill in the saved paths, including when you start a new session. This prompt authorizes local application and staging, not commits or publication.

════ PROMPT STARTS BELOW THIS LINE ════

Follow the migrate-lifecycle skill and runbook in `<toolkit-checkout>`. Apply the reviewed migration described by `<manifest-path>` and `<preview-path>` to the projects listed there.

Verify the fixed source revisions and current Git state again. If the source or proposed mapping changed, or compatible validators are not installed, stop the affected project and explain what needs resolution. Do not silently expand the reviewed scope.

Run serially. Apply and stage the rehearsed changes, verify preservation and references, and confirm a repeat is a no-op. Report each project's result and any blockers. Do not install validators, change global configuration, commit, push or open a PR.

If the accepted preview includes requirements extraction, verify the structural no-op first, then apply only its saved additive patch under the extraction procedure below. Verify the final tree and unchanged source documents. Record structural completion and draft extraction separately; the structural runner alone cannot apply or recognize the combined result.

════ PROMPT ENDS ABOVE THIS LINE ════

The delimiters are not part of the prompt.

## Check discovery coverage before moving records

Inventory document consumers along with the files. Check the Project Map, phase skills, briefing/session recovery, validators and registered search collections against the target paths. Supporting old folders does not establish support for every new location or metadata field.

For QMD installations, inspect the existing collections with `qmd --index agent-docs collection list`. A collection restricted to legacy folders can lose designs, plans, reviews and retrospectives after their moves. Include the exact collection-pattern update in the migration scope, preserve its canonical root, exclusions and private visibility, and obtain any missing configuration authority. Do not register transient worktrees or duplicate clones. After the authorized changes, run `qmd --index agent-docs update` and verify the migrated records are found through the intended collections. This is lexical indexing; model downloads, embeddings, daemons and MCP servers remain separate actions.

A source rehearsal verifies file transformations; it does not prove that an installed harness or search index can discover the result. Keep unavailable consumer checks and configuration changes explicit in the per-project disposition.

## Establish the baseline

Read project instructions and the Project Map. Do not assume `docs/` or a numbered folder identifies the active working-memory root. Inspect dirty files, local and remote commits, worktrees and other writers. Keep incompatible sessions read-only during application.

Capture a fixed Git revision and inventory all affected records and attachments, including file modes and existing broken references. Rehearse on a disposable copy. Preserve ignored historical evidence; do not sweep it into Git merely because it is inventoried.

## Decide a mapping once

The usual legacy transition is:

| Existing location | Target |
|---|---|
| `0-brainstorms/` | unchanged |
| `1-discovery/` | `1-research/` |
| `2-design/` | `3-design/`, except requirements records |
| `3-plans/` | `4-plans/` |
| `4-reviews/` | `5-reviews/`, except process retrospectives and lessons |
| Requirements records | `2-requirements/` when standalone |
| Process retrospectives | `6-retros/` |
| Standalone lessons | `6-retros/lessons/<workstream>/` |

Inspect type and content before applying whole-directory moves. Retain historical types except the supported research alias. Create all seven numbered lifecycle folders in each declared working-memory root, adding `.gitkeep` to empty folders. This does not require a document or phase in each folder; nested lesson and asset folders remain on demand. Preserve frozen evidence and separate live references from historical path examples.

The model may propose classifications and exact reference edits. The operator or delegated scope resolves consequential ambiguity. Once settled, save the explicit mapping and execute it mechanically; do not ask a model to freely reorganize or rewrite the documents during application.

## Assess requirements and optionally extract

Every preview identifies the current requirements owner, including a sufficient brief embedded in a design or plan. Record whether a standalone requirements document would improve discovery or handoff. Reuse a sufficient existing requirements document. Extraction is optional and must be included in the requested project or batch scope; do not fill an empty requirements folder merely to complete the layout.

When extraction is requested, read the [requirements quality contract](../skills/start-requirements/references/requirements-contract.md) and [SDD requirements template](../skills/start-requirements/references/requirements-template.md), using project overrides where present. Prepare an additional brief or PRD for each selected coherent initiative in the declared `2-requirements/` folder. Public application repositories with private working memory keep these records in the private repository. Public visibility does not override that routing.

Keep the original brainstorms, designs, plans and their embedded requirements intact. Do not remove sections, replace requirement tables with pointers or add extraction-related edits to those sources. The structural migration may still move files, normalize metadata and repair references as explicitly previewed. Compare original sources with that structural target, then require byte-for-byte source preservation through extraction. The new document references the migrated source paths and fixed source revisions; it does not depend on rewriting the originals.

Use the template's readable `ID | Requirement | Acceptance criteria` table. Retain existing IDs with source context, disambiguating collisions rather than silently renumbering historical obligations. For requirements inferred from intent, journeys or constraints, give them distinct IDs and label them as inferences. Capture relevant success, failure and recovery outcomes without converting implementation tasks into product requirements. Missing acceptance evidence, uncertain numerical targets and conflicting decisions remain visible gaps. Do not invent acceptance, delivery or personal review.

Include a coverage table in the derived document with the original source path at its fixed revision, migrated live link, section/ID, extracted requirement IDs and disposition. Dispositions distinguish explicit source statements, inferences, exclusions with reasons and unresolved conflicts. Keep historical increments separate from current product scope. This lets a reviewer assess omissions and interpretations without modifying the originals.

New extractions start as `draft`. Their `created` and `updated` dates are the extraction date; the source documents retain their original dates and review history. Attribute actual contributors to the new document; source authorship stays in the cited sources and is not copied as new contribution. Document control identifies the extraction date, all source revisions and the retained authoritative scope owner. A derived draft neither supersedes its sources nor inherits `reviewed_by`, approval or shipped status. Accepting it as a new scope owner is later work under actual authority, not a migration side effect.

### Rehearse and apply the additive patch

The manifest runner handles tracked-file structural changes and metadata, not PRD generation. Do not invent an extraction flag or place new documents in its existing-file `edits` list. Keep the authored patch outside the target repositories alongside the structural manifest and reports.

1. Rehearse the structural manifest against its fixed source revision. Record its target tree and verify preservation, installed validation and the structural no-op.
2. In a disposable copy of that structural target, create the exact additional documents, including their coverage tables. Save an additions-only patch and the final target tree for each Git repository. Check scope coverage, source preservation, new-document metadata, relative links and discovery coverage. The combined preview includes both patches and both target trees; extraction drafting changes no live project files.
3. Under apply authority for the accepted preview, recheck the fixed source and apply the structural manifest. Verify its target tree and no-op before applying the saved additive patch. Check for destination collisions, apply only the exact rehearsed additions and stage them. Verify the final tree, source bytes, metadata, links and installed validator again. Do not regenerate the prose during application.
4. On interruption, inspect the actual tree and existing checkpoint first. For staged work, compare the index tree and confirm there are no unexplained unstaged or untracked files; HEAD alone does not identify completion. At the clean original source, start structural application. At the exact structural target, continue only with its pending extraction patch. At the exact final target, report the recorded work already applied and skip both effects. An unexplained partial effect or changed source requires reconciliation. A final tree containing a PRD differs from the structural runner's target, so rerunning that runner can report source drift; it does not prove extraction failed.

Report structural migration and requirements disposition separately: reused, extraction not requested, extraction unnecessary, drafted or blocked. Conflicting requirements can prevent acceptance of a draft while an independently safe structural migration completes. A combined apply request stops on an unresolved extraction patch unless its scope explicitly permits delivering the structural part separately. State that boundary in the preview rather than silently dropping requested extraction.

## Run one project or a selected batch

The runner is [scripts/migrate-lifecycle.py](../scripts/migrate-lifecycle.py). It uses the same manifest for one project or many. Save this JSON outside the selected repositories, replacing the placeholders with real paths and full commit IDs:

```json
{
  "projects": [
    {
      "repo": "<repository-root>",
      "revision": "<full-source-commit>",
      "memory": "docs",
      "moves": {
        "docs/2-design/example.md": "docs/3-design/example.md"
      },
      "edits": [
        {
          "path": "README.md",
          "old": "docs/2-design/example.md",
          "new": "docs/3-design/example.md",
          "count": 1
        }
      ]
    }
  ]
}
```

Add another object to `projects` for each selected repository. Repository paths can be absolute or relative to the manifest. `revision` must be a full Git commit ID. `memory`, move paths and edit paths are repository-relative; use `"memory": "."` for a working-memory repository whose root contains the lifecycle folders. Omit `memory` for a public-instruction-only change. Optional `ignore_revisions` is a list of reviewed mechanical commit IDs for metadata date lookup. Optional `relationship_conversions` contains the explicit legacy-field conversions described below. Unknown fields are refused.

```bash
python3 scripts/migrate-lifecycle.py --manifest <manifest.json>
python3 scripts/migrate-lifecycle.py --manifest <manifest.json> --apply
```

The first command rehearses in disposable local clones and returns JSON containing exact patches, source revisions, target trees and per-project results. It does not change project files. Save the report outside the selected repositories. It may contain private document content, so keep it in an appropriate private location.

The second rehearses the same fixed inputs, then applies and stages the patch in each clean matching repository. It normalizes metadata first, performs explicit relationship conversions and exact replacements at the original paths, then moves explicitly listed files. When `memory` is supplied, it also creates all seven numbered lifecycle folders beneath that root, with an empty `.gitkeep` in each empty folder. Existing placeholder files remain intact. Omit `memory` for public-instruction-only work so no lifecycle folders are added there. Ignored required folders block the project rather than silently omit the scaffold. Include every owned attachment in `moves`; directories are not inferred or recursively moved. Each replacement needs a positive exact `count`. Frontmatter edits may change relationship references, but must preserve other header fields after metadata normalization.

### Convert legacy relationship fields explicitly

After checking the owning document's meaning, use `relationship_conversions` to merge `inputs` or `amended_by` into `related`. This is an optional, exact conversion, not general support for custom fields or automatic schema inference. Each entry requires exactly `path`, `field`, `old` and `new`. `path` names the original tracked file; `old` must match once. For example:

```json
"relationship_conversions": [
  {
    "path": "docs/2-design/example.md",
    "field": "inputs",
    "old": "inputs: [source.md]\nrelated: [source.md, evidence.md]\n",
    "new": "related: [source.md, evidence.md]\n"
  }
]
```

The conversion must remove the selected legacy field and produce one `related` field. It can change only that field and `related`; dates, status, authors, review history, other metadata and document body bytes must remain intact. Merge all references, remove duplicates and supply their final file-relative paths in the exact replacement. Preserve any explanation of amendment or input roles in the original body. A partial amendment does not mean full supersession. The runner checks supported link regressions, but an operator must still check that the explicit replacement retains every intended relationship; a resolving link alone does not establish its meaning.

If a legacy target belongs to another repository, verify its owning path and use a GitHub URL pinned to its full source commit, with `blob` for files and `tree` for directories. Do not repair missing titles, authors or statuses through a relationship conversion. Recover those from evidence and review them separately.

The runner checks for new unresolved Markdown links using the toolkit's existing supported link parser. It retains pre-existing failures, rejects collisions and unsafe paths, and verifies the staged Git tree matches the rehearsed tree. Every originally tracked file must still be tracked at its mapped destination or unchanged path. If an ignore rule would omit a moved file, the rehearsal blocks before the project is changed. Review an exact destination exception in `.gitignore`, then refresh the preview; the runner does not force-add files. It does not infer bare-text references or validate all metadata relationship syntax; the integrated comparison below remains required. Previously untracked ignored files are not migrated. Inspect and resolve any ignored evidence that belongs with a moved document separately; never delete it or assume it followed the tracked files.

A batch runs serially. Exit code 1 means at least one project is blocked; other independent entries still run. Malformed top-level input exits 2. Results distinguish `previewed`, `applied`, `already-applied` and `blocked`. A repeat recognizes the exact staged or committed target tree; unrelated subsequent changes require reconciliation. A batch is not one transaction across repositories.

The runner installs no validators and makes no commits, pushes, PRs or merges. Keep each project's checkpoint and commit permissions explicit. Do not call a project complete until the broader validation below passes.

## Normalize metadata with the existing command

Run from the toolkit checkout. Substitute the selected working-memory root and its captured Git commit:

```bash
python3 scripts/migrate-frontmatter.py --root <working-memory-root> --source-revision <source-commit>
python3 scripts/migrate-frontmatter.py --root <working-memory-root> --source-revision <source-commit> --apply
```

The first command previews. The second requires apply authority, a clean selected tree and compatible installed validators. Neither moves folders, edits project instructions, installs hooks, commits nor pushes.

It preserves creation dates and existing `updated` values, backfills missing updates from Git author history, and changes `type: discovery` to `research`. It leaves bodies and other metadata intact. Unsupported scalar syntax, missing history and conflicting values stop conversion rather than supply invented dates.

Prefer metadata conversion before mechanical moves. For already-moved files use `--path-map <mapping.json>` with old-to-current paths relative to the working-memory root. When later genuine updates must count, select current history and omit only reviewed mechanical commits using repeatable `--ignore-revision <commit>`. See the [full convention](guide-project-structure-and-conventions.md#102-folder-renames).

## Verify before completing a project

- Account for every source file at its expected destination, including assets and modes.
- Check all seven numbered lifecycle folders exist in the declared working-memory root, with `.gitkeep` in empty folders. Folder presence grants no authority and requires no artifact.
- Preserve bodies except the exact approved live-reference edits, and preserve all review attribution and approval evidence.
- Compare links and metadata relationships against the baseline; introduce no new failures.
- Verify the installed validator and actual hook entry point, not just source files.
- Repeat the structural transformation and confirm zero further edits before any extraction patch. For a combined migration, also verify its recorded final tree and skip already completed effects on resume.
- When extraction is included, verify its source coverage, draft metadata, retained authority and unchanged source documents against the structural target. Validate the new records and discovery coverage separately from preservation of the originals.
- Read the integrated diff and update the project's existing instructions and progress records.

Record real commits after they exist. Publication and installation remain separate from verified local work. After an interruption, inspect the actual effect and checkpoint before repeating it. A dirty tree or unexplained partial effect is a recovery case, not permission to overwrite.

## Choose a model by the remaining judgment

The scripts perform the mechanical changes. The agent still needs to interpret project instructions, distinguish historical evidence from live references, classify mixed documents, prepare an exact mapping and respond correctly to failures. A command runner alone does not supply that judgment.

These are recommendations for this workflow, not measured migration benchmarks:

| Situation | Suggested harness/model | Reason and escalation |
|---|---|---|
| First pilot or a project with mixed document types | Claude Code with current Sonnet, such as Sonnet 5.5 | Start with enough reasoning capacity to assess classification and preservation. Use the first preview to learn whether the next projects are routine. |
| Conventional layout, or routine execution of a settled mapping | Antigravity with Gemini 3.8 Flash at Medium thinking | A candidate for using a separate capacity pool on repeatable tool work. Check one representative result before using it for a batch. |
| You prefer OpenCode | OpenCode with a configured model you have used successfully for repository tool use; use Sonnet for ambiguous inspection or a budget model for settled mappings | OpenCode is the harness; the chosen provider/model determines reasoning and cost. Do not assume every configured model follows the skill equally well. |
| Conflicting authority, unclear classification, unexplained failures or possible content loss | Escalate to a stronger reasoning model, such as Opus 5.5 in Claude Code, or ask the operator | Resolve the specific uncertainty before changing more files. A routine migration does not need the strongest model throughout. |

A cheaper model can be sufficient once the mapping is explicit, but it must still read failures and respect the stop conditions. Use ordinary reasoning for routine execution; increase effort or model capability when actual ambiguity appears. Do not choose a budget model merely because the batch is large: each project's interpretation still needs checking. Switching models does not change the required verification or authorize parallel workers.

Model availability checked 2026-10-31: [Antigravity's model list](https://antigravity.google/docs/models) includes Gemini 3.8 Flash and thinking choices; [Claude Code model configuration](https://support.claude.com/en/articles/11940350-claude-code-model-configuration) lists Sonnet and Opus 5.5; [Claude's model guidance](https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code) distinguishes routine work from harder reasoning. [OpenCode's model documentation](https://opencode.ai/docs/models) explains provider/model selection. Check the active model picker and account limits before running; this guide does not establish your cheapest option or remaining quota.

Keep model selection outside the migration skill and manifest. See the [general routing guide](guide-ai-model-and-effort-routing.md) for capability, privacy and quota trade-offs. No end-to-end comparison of these models on this migration has been performed.
