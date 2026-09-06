# drift-guard

A push gate and merge reporter that refuses stale project records at `git push` and reports what a merge left behind.

## What it checks

1. **Check A: Frontmatter on lifecycle documents.**
   Markdown files in the push under lifecycle directories (`0-brainstorms/`, `1-discovery/`, `2-design/`, `3-plans/`, `4-reviews/`, `adrs/`) must have:
   - YAML frontmatter block starting at byte 0 (`---`).
   - Required fields: `title`, `type`, `authors`.
   - Lifecycle types require `date` and `status`.
   - `status` must be one of six closed values: `draft`, `approved`, `in-progress`, `shipped`, `resolved`, `superseded`.

2. **Check C: Shipped roadmap line pairing.**
   Lines added to `ROADMAP.md` under `Recently shipped` linking lifecycle documents require those documents to have `status: shipped`.

3. **Check B: Changelog pairing (opt-in).**
   When `scripts/githooks/drift-guard.on` exists, any push containing `feat`, `fix`, or `perf` commits requires `CHANGELOG.md` in the push range.

## What it deliberately does not do

- **Does not touch the network on push.** `housekeep check --push` reads only local files. Network calls slow down pushes, fail offline, and encourage `--no-verify`.
- **Does not check Markdown files outside lifecycle directories.** Exempts `notes/`, `assets/`, `imports/`, `guides/`, root documents (README, ROADMAP, CHANGELOG), and published documentation.
- **Does not mandate a roadmap update for every feature.** Historical measurement showed a 44% false-positive rate because many features never had an upfront roadmap line.
- **Does not run `fix` automatically from a hook.** Deleting branches or removing worktrees requires explicit user confirmation.
- **Does not delete remote branches.** Remote branch deletion is handled by GitHub repository settings (`delete_branch_on_merge=true`).

## False-positive measurement

Measured on 2026-09-04 against full git history:

| Repository | No frontmatter | In a lifecycle directory |
|---|---|---|
| crossrev | 22 | 0 |
| penmark | 29 | 11 |
| copydesk | 16 | 0 |
| quotacap | 6 | 0 |

Scoped to lifecycle directories, false positives drop to zero across crossrev, copydesk, and quotacap. The 11 findings in penmark represent true drift addressed via backfill.

## Install

```bash
HOOK_SRC=~/Projects/carlos/claude-code-resources/git-hooks/drift-guard
TARGET=~/Projects/carlos/<repo>

mkdir -p "$TARGET/scripts/githooks"
cp "$HOOK_SRC/housekeep" "$HOOK_SRC/pre-push" "$TARGET/scripts/githooks/"
chmod +x "$TARGET/scripts/githooks/housekeep" "$TARGET/scripts/githooks/pre-push"
git -C "$TARGET" config core.hooksPath scripts/githooks
```
