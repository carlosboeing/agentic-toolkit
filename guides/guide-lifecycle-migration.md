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

Work serially. Inspect and propose an explicit mapping; raise ambiguous classifications instead of guessing. Use the deterministic runner to rehearse against a fixed source revision in a disposable copy. Check installed validator compatibility. Keep the manifest and preview in an appropriate private location outside the target repository; ask for that location if none is established.

Show the proposed changes, verification results, blockers and unresolved decisions. Give me the saved manifest and preview paths so another session can resume.

Stop after the preview. Do not edit the selected projects, install validators, change global configuration, commit, push or open a PR.

════ PROMPT ENDS ABOVE THIS LINE ════

The delimiters are not part of the prompt.

### Select several projects or discover a bounded batch

For named projects, replace the preview prompt's first sentence with: "Use the migrate-lifecycle skill to prepare migration previews for these project roots: `<project-root-1>`, `<project-root-2>`." Keep the rest of the prompt. Each repository, including a private companion when present, gets its own manifest entry and result.

For all projects under a directory, replace that sentence with: "Discover candidate projects only beneath `<search-root>`. Show me the deduplicated repository list and exclusions, then wait for my selection before preparing previews." This first step discovers the scope. It does not authorize migration of every repository it finds. Once selected, preview serially; report blocked projects and continue independent ones.

### Continue from an accepted preview

Fill in the saved paths, including when you start a new session. This prompt authorizes local application and staging, not commits or publication.

════ PROMPT STARTS BELOW THIS LINE ════

Follow the migrate-lifecycle skill and runbook in `<toolkit-checkout>`. Apply the reviewed migration described by `<manifest-path>` and `<preview-path>` to the projects listed there.

Verify the fixed source revisions and current Git state again. If the source or proposed mapping changed, or compatible validators are not installed, stop the affected project and explain what needs resolution. Do not silently expand the reviewed scope.

Run serially. Apply and stage the rehearsed changes, verify preservation and references, and confirm a repeat is a no-op. Report each project's result and any blockers. Do not install validators, change global configuration, commit, push or open a PR.

════ PROMPT ENDS ABOVE THIS LINE ════

The delimiters are not part of the prompt.

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

Add another object to `projects` for each selected repository. Repository paths can be absolute or relative to the manifest. `revision` must be a full Git commit ID. `memory`, move paths and edit paths are repository-relative; use `"memory": "."` for a working-memory repository whose root contains the lifecycle folders. Omit `memory` for a public-instruction-only change. Optional `ignore_revisions` is a list of reviewed mechanical commit IDs for metadata date lookup. Unknown fields are refused.

```bash
python3 scripts/migrate-lifecycle.py --manifest <manifest.json>
python3 scripts/migrate-lifecycle.py --manifest <manifest.json> --apply
```

The first command rehearses in disposable local clones and returns JSON containing exact patches, source revisions, target trees and per-project results. It does not change project files. Save the report outside the selected repositories. It may contain private document content, so keep it in an appropriate private location.

The second rehearses the same fixed inputs, then applies and stages the patch in each clean matching repository. It normalizes metadata first, performs exact replacements at the original paths, then moves explicitly listed files. When `memory` is supplied, it also creates all seven numbered lifecycle folders beneath that root, with an empty `.gitkeep` in each empty folder. Existing placeholder files remain intact. Omit `memory` for public-instruction-only work so no lifecycle folders are added there. Ignored required folders block the project rather than silently omit the scaffold. Include every owned attachment in `moves`; directories are not inferred or recursively moved. Each replacement needs a positive exact `count`. Frontmatter edits may change relationship references, but must preserve other header fields after metadata normalization.

The runner checks for new unresolved Markdown links using the toolkit's existing supported link parser. It retains pre-existing failures, rejects collisions and unsafe paths, and verifies the staged Git tree matches the rehearsed tree. It does not infer bare-text references or validate all metadata relationship syntax; the integrated comparison below remains required. Ignored files are not migrated. Inspect and resolve any ignored evidence that belongs with a moved document separately; never delete it or assume it followed the tracked files.

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
- Repeat the transformation and confirm zero further edits.
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
