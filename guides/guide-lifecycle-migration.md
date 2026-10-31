# Migrate lifecycle documentation in existing projects

This runbook covers adoption in one project or an explicitly selected batch. It separates classification decisions from deterministic file and metadata changes. It is for an operator or coding agent using the toolkit checkout.

## Start with an explicit scope

Invoke `/migrate-lifecycle <project-path>` after the skill is installed, or ask an agent to follow this runbook for named projects. Preview is the default. To cover all projects, name the search roots and review the discovered repository list before applying changes.

Use the same procedure for one or many projects. Work serially and record each project's source revision, working-memory root, mapping, result and next recovery step. A blocked project need not block unrelated repositories. A batch is complete only when every selected project has a recorded disposition.

A nested private repository is a separate Git target. Migrate its working-memory records there and public instructions in their owning repository. Never combine them in one commit or put private source references in public tracking.

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

Inspect type and content before applying whole-directory moves. Retain historical types except the supported research alias. Keep optional directories absent until needed. Preserve frozen evidence and separate live references from historical path examples.

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

The second rehearses the same fixed inputs, then applies and stages the patch in each clean matching repository. It normalizes metadata first, performs exact replacements at the original paths, then moves explicitly listed files. Include every owned attachment in `moves`; directories are not inferred or recursively moved. Each replacement needs a positive exact `count`. Frontmatter edits may change relationship references, but must preserve other header fields after metadata normalization.

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
- Preserve bodies except the exact approved live-reference edits, and preserve all review attribution and approval evidence.
- Compare links and metadata relationships against the baseline; introduce no new failures.
- Verify the installed validator and actual hook entry point, not just source files.
- Repeat the transformation and confirm zero further edits.
- Read the integrated diff and update the project's existing instructions and progress records.

Record real commits after they exist. Publication and installation remain separate from verified local work. After an interruption, inspect the actual effect and checkpoint before repeating it. A dirty tree or unexplained partial effect is a recovery case, not permission to overwrite.

## Choose a model by the remaining judgment

A budget model can follow an explicit mapping and deterministic commands. Use a stronger model or human input for ambiguous classification and unexpected failures. Verify one representative project before broad batch use. No particular provider, model, or harness is required, and mechanical checks do not prove agent reliability.
