# Toolkit scripts

Skills coordinate requests and contextual decisions. Scripts perform repeatable operations and report what happened. Keep each operation implemented once; callers and compatibility wrappers delegate to its owner.

## Catalog

| Entry point | Responsibility | Workflow owner |
|---|---|---|
| [`sync-toolkit.sh`](sync-toolkit.sh) | Copy skills, hooks and plugins; configure installations | [`sync-toolkit`](../skills/sync-toolkit/) skill or direct CLI |
| [`toolkit-rollout.py`](toolkit-rollout.py) | Preview exact repository hook changes, apply reconciled targets and verify installation/publication | `sync-toolkit` skill |
| [`register_hooks.py`](register_hooks.py) | Merge hook settings, record changes and report required manual actions | Called by `sync-toolkit.sh` |
| [`migrate-lifecycle.py`](migrate-lifecycle.py) | Rehearse/apply explicit lifecycle mappings | [`migrate-lifecycle`](../skills/migrate-lifecycle/) skill and [runbook](../guides/guide-lifecycle-migration.md) |
| [`migrate-frontmatter.py`](migrate-frontmatter.py) | Normalize lifecycle dates and types without rewriting prose | Migration runner or explicit CLI |
| [`check-relative-links.py`](check-relative-links.py) | Check public tracked Markdown and frontmatter relationships | CI or explicit CLI; implementation in [`check_relative_links.py`](check_relative_links.py) |
| [`githooks/`](githooks/) | Installed Git hooks for this repository | Canonical distributed hooks live under [`git-hooks/`](../git-hooks/); local customizations remain distinct |

Other executable tools belong beside their owners: session readers in [`resume-session`](../skills/resume-session/scripts/), scheduler helpers in [`schedule-resume`](../skills/schedule-resume/scripts/), the [plan checker](../skills/start-planning/scripts/check-plan.py) and [Penmark validator](../skills/penmark-comments/scripts/validate-penmark-comments.mjs). Harness adapters live in [`hooks/`](../hooks/). [`skills/sync-skills.sh`](../skills/sync-skills.sh) remains a compatibility forwarder. [`install-superpowers.sh`](../plugins/install-superpowers.sh) remains the documented rollback tool.

## Repository rollout

Python 3 and the existing installer dependencies are required. Select targets explicitly and put the report outside all selected repositories:

```sh
python3 scripts/toolkit-rollout.py audit --repo "<project>" --report "<new-report.json>"
python3 scripts/toolkit-rollout.py apply --report "<report.json>"
python3 scripts/toolkit-rollout.py smoke --report "<report.json>"
python3 scripts/toolkit-rollout.py verify --report "<report.json>" --require tested
python3 scripts/toolkit-rollout.py verify --report "<report.json>" --require published
```

Repeat `--repo` to select a batch. Independent nested private repositories are included as separate targets. Audit changes only its new report. Apply checks the recorded source and destination baseline, then delegates copying to `sync-toolkit.sh`; it never stages, commits, pushes or merges. It preserves custom privacy hooks and blocks other unknown hooks, changed destinations, linked paths or custom hook-path configuration. Blocked entries remain visible while independent targets proceed. A no-op repeat preserves installed files.

The version 1 JSON report contains source revision and file hashes, each repository's original HEAD/status/configuration, exact relative file paths, expected content/modes, preservation decisions, blockers, installer output and current verification results. Installation, smoke test, committed content and publication have separate states. Reports may contain private paths; keep them outside public commits. A changed source needs a new audit. Existing reports are not overwritten by a new audit.

The smoke operation runs the installed `housekeep` script in a disposable Git repository. A valid lifecycle document must pass and a broken relationship must fail. This does not test custom privacy hooks, every validator rule or runtime harness events. Changed installed files invalidate the smoke result.

Publication verification queries the target's configured remote upstream afresh and checks content and executable modes in that commit. It does not assume main, fetch objects, push or merge. Fetch through the project's normal process when the remote commit is unavailable locally. The checked remote/ref appears in the report. Publishing a feature branch does not establish merge. Unrelated application work stays visible and unchanged.

Exit codes: `0` means the requested check passed, `1` means a selected target is blocked or a required stage is unfinished, and `2` means invalid arguments, a stale source or an unsupported report. A successful audit does not establish installation or publication. Inspect every entry after a nonzero batch result.

## Harness installation

```sh
./scripts/sync-toolkit.sh --dry-run --harness --registration-report "<new-preview.json>"
./scripts/sync-toolkit.sh --harness --registration-report "<new-install.json>"
```

A registration report lists settings-file hashes and events, including manual `ACTION` items such as hook trust. It covers hook registration, not every copied skill/plugin and not runtime smoke tests. Each invocation uses a new report path. Dry run writes its explicitly requested report but does not change harness settings.

Missing required sources or failed registration make installation exit nonzero. Absent harnesses are skipped. Manual actions remain outstanding even when settings registration succeeds. The installer summary describes installation only; the skill coordinates further tests and publication within the actual request.

The lower-level `--no-sidecars` flag lets the rollout runner preflight and execute each Git target independently. Normal direct installation retains its existing automatic companion expansion. Local operator configuration and fleet discovery remain supported through [`sync-toolkit.conf.example`](sync-toolkit.conf.example).
