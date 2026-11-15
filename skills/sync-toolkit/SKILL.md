---
name: sync-toolkit
description: Audit, apply or resume agentic-toolkit updates across user-level harness installations and explicitly selected repositories. Coordinate deterministic reports, conflicts, smoke tests and authorized publication. Use for toolkit synchronization or rollout requests, not general repository cleanup or lifecycle-document migration.
---

# Sync the toolkit

Use the toolkit's scripts for inventories, copying and verification. Own target selection, contextual decisions and authorized follow-through. Keep installation, registration, runtime tests, commits, publication and merge evidence separate.

## Establish scope

Resolve the source checkout from the current project, existing operator configuration or an explicit path. Read its instructions, `scripts/README.md` and current sync configuration. The installed skill hub is derived state; it may not contain the root scripts. If the checkout is unavailable, report that gap rather than inventing a path or downloading a replacement.

Use the current request as authority. Record the intended result: audit only, local installation, or repository rollout through a specified publication stage. Existing authorization persists across steps; ask only for missing scope or an unresolved consequential choice. A generic sync starts with user-level harness inspection. Repository changes require an explicit target or selected batch; never silently add `--all-repos`.

Read live source/target Git state, project instructions and worktrees. Follow each project's isolation rules. Preserve unrelated application work, custom hooks and private/public repository boundaries. Keep reports and logs private when they contain local paths or private target names. Use a new report path outside all selected Git targets.

## Repository audit and apply

From the source checkout, preview explicit targets:

```sh
python3 scripts/toolkit-rollout.py audit --repo "<project>" --report "<new-report.json>"
```

Repeat `--repo` for a selected batch. The runner includes independent nested private repositories. Inspect every report entry, source revision/content hashes, exact paths, baseline state and blockers. Its audit writes only the report. Resolve ambiguous ownership or custom configuration with evidence; never call an untracked file ignored without checking Git. Known custom privacy hooks are preserved and are outside the stock hook smoke-test claim.

After apply authority, use the same report:

```sh
python3 scripts/toolkit-rollout.py apply --report "<report.json>"
python3 scripts/toolkit-rollout.py smoke --report "<report.json>"
python3 scripts/toolkit-rollout.py verify --report "<report.json>" --require tested
```

Apply uses the existing `sync-toolkit.sh` installer after preflight. It never stages, commits or pushes. Source or destination drift invalidates affected work; inspect it and prepare a fresh audit rather than editing the baseline to pass. Blocked targets do not prevent independent targets proceeding. The smoke check invokes installed `housekeep` against valid and broken fixtures in a disposable Git repository; it does not establish behavior of custom privacy hooks or harness events.

## Harness installation

Preview the existing global installer and retain the output and structured registration report:

```sh
./scripts/sync-toolkit.sh --harness --dry-run --registration-report "<new-preview-registration.json>"
```

Inspect the planned hub/spoke changes and existing tools. Install only within the request's authority, using a separate new registration report:

```sh
./scripts/sync-toolkit.sh --harness --registration-report "<new-install-registration.json>"
```

The registration report lists settings writes and `ACTION` events. It covers registration, not every copied skill or plugin. Retain the installer output for those changes and compare relevant source/destination contents. Failures remain failures. Hook trust, absent external plugins and unavailable runtime tests remain explicit work. Read the applicable hook README and harness-hooks reference before probing behavior. Run focused checks in supported harnesses; a copied executable or settings entry alone is not proof that a harness ran it. Honor local customizations and third-party ownership. Do not remove, upgrade or install unrelated tools under a generic sync request.

## Publish and reconcile

When publication is included, use the exact managed paths from the repository report. Inspect the diff and staged changes, including new files and executable modes. Exclude `preserved` custom hooks and unrelated application edits. Follow branch/PR policies and existing commit authority; a sync request alone does not imply merging. After publication:

```sh
python3 scripts/toolkit-rollout.py verify --report "<report.json>" --require published
```

This checks the configured upstream branch through a fresh remote query and verifies expected committed contents and modes. The remote commit must be available locally for content inspection; fetch through the project's normal read-only process when it is not. State which remote/ref was checked. Publication on a feature branch does not establish merge into main. Keep source implementation delivery separate from installed-copy delivery.

For an interrupted run, read the existing report, inspect current state and use `verify`; repeat apply only for reconciled unfinished effects. Retain failure evidence. Finish with each selected target's installation, smoke-test, commit and publication result, custom exceptions, unrelated work and next action. Completion requires evidence for every requested stage. Use `migrate-lifecycle` for separately authorized document migrations.
