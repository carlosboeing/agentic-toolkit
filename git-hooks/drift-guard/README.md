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

## Modes

| Mode | Scope | Network | Exit | Caller |
|---|---|---|---|---|
| `check --push <base> <head>` | frontmatter, roadmap pairing, changelog | never | 1 on findings | `pre-push` hook |
| `check` | last pull window (`ORIG_HEAD..HEAD`) plus stale refs | yes | always 0 | `post-merge` hook |
| `audit` | every local branch and registered worktree | yes | always 0 | `/housekeeping audit` (default) |
| `fix` | deletes the audit-removable set | yes | always 0 | `/housekeeping fix` |

## Classification vocabulary

`housekeep audit` outputs one line per non-protected branch, one line per noteworthy worktree, and a closing summary.

### Scope line (printed first)

```
  audit <owner/repo> at <toplevel>: <Nb> branches (<P> protected), <Mw> worktrees, <K> pull requests resolved, <J> unresolved
```

When origin is missing or not a GitHub URL:

```
  audit <toplevel>: no GitHub identity (origin missing or unparseable); pull-request state unresolved for all <N> branches
```

### Branch lines

```
  branch <B>: pull request #<N> merged, safe to remove
    worktree <path> holds it, so remove that first
  branch <B>: pull request #<N> merged, local behind its head, safe to remove
  branch <B>: pull request #<N> open, kept
  branch <B>: pull request #<N> closed unmerged, kept
  branch <B>: commits past pull request #<N> (<state>), kept
  branch <B>: merged pull request #<N>, but <oid12> is not in <base> history, kept
  branch <B>: diverged from pull request #<N> head, kept
  branch <B>: no pull request found, kept
  branch <B>: pull request #<N> merged, worktree <path> <blocker>, kept
  branch <B>: checked out in the main worktree, kept
  branch <B>: unresolved (<reason>), kept
```

`<blocker>` describes the worktree state preventing branch removal: `has uncommitted changes`, `is locked`, or `holds ignored files`.

### Worktree lines

```
  worktree <path> (<B>): uncommitted changes, kept
  worktree <path> (<B>): locked (<reason>), kept
  worktree <path> (<B>): ignored files (<n>: <p1>, <p2>, ...), kept
  worktree <path>: detached HEAD, not managed
  worktree <path>: directory missing, metadata prunable
```

The main worktree is counted in the scope line and never listed. Detached worktrees are reported and not managed by `fix`.

### Summary line (printed last)

```
  <R> removable, <K> kept, <J> unresolved, across <Nb> branches and <Mw> worktrees
  housekeep fix
```

The `housekeep fix` hint prints only when `<R>` is greater than zero.

## Limitations

- **Branch names containing double quotes**: Branch names containing `"` are unsupported by the flat JSON record parser. They degrade safely toward keeping and are reported as `unresolved`.
- **Detached worktrees**: Detached HEAD worktrees do not map to a branch and are never deleted or modified by `fix`.
- **Ignored files**: Unlike `git worktree remove` which silently deletes ignored files, `housekeep` treats ignored files as blockers and refuses removal until they are manually cleared or verified.

## What it deliberately does not do

- **Does not touch the network on push.** `housekeep check --push` reads only local files. Network calls slow down pushes, fail offline, and encourage `--no-verify`.
- **Does not check Markdown files outside lifecycle directories.** Exempts `notes/`, `assets/`, `imports/`, `guides/`, root documents (README, ROADMAP, CHANGELOG), and published documentation.
- **Does not mandate a roadmap update for every feature.** Historical measurement showed a 44% false-positive rate because many features never had an upfront roadmap line.
- **Does not run `fix` automatically from a hook.** Deleting branches or removing worktrees requires explicit user confirmation.
- **Does not force-remove worktrees.** Never passes `--force` to `git worktree remove`.
- **Does not delete remote branches.** Remote branch deletion is handled by GitHub repository settings (`delete_branch_on_merge=true`).

## False-positive measurement

### Push gate frontmatter check (measured 2026-09-04)

Measured against full git history:

| Repository | No frontmatter | In a lifecycle directory |
|---|---|---|
| crossrev | 22 | 0 |
| penmark | 29 | 11 |
| copydesk | 16 | 0 |
| quotacap | 6 | 0 |

Scoped to lifecycle directories, false positives drop to zero across crossrev, copydesk, and quotacap. The 11 findings in penmark represent true drift addressed via backfill.

### Full audit branch and worktree verification (measured 2026-09-17)

Measured across 5 active local repositories including nested `.workbench` sidecars (9 git repositories total):

| Repositories scanned | Branches evaluated | Worktrees evaluated | Removable lines | Wrong on inspection |
|---|---|---|---|---|
| 9 | 17 | 12 | 0 | 0 |

Across all repositories, every open branch, working branch without a pull request, and dirty or ignored-holding worktree was correctly kept. Protected branches were derived accurately without manual configuration. Zero false positives and zero lines wrong on inspection.

## Install

```bash
HOOK_SRC=<path-to-toolkit>/git-hooks/drift-guard
TARGET=<path-to-repo>

mkdir -p "$TARGET/scripts/githooks"
cp "$HOOK_SRC/housekeep" "$HOOK_SRC/pre-push" "$HOOK_SRC/post-merge" "$TARGET/scripts/githooks/"
chmod +x "$TARGET/scripts/githooks/housekeep" "$TARGET/scripts/githooks/pre-push" "$TARGET/scripts/githooks/post-merge"
git -C "$TARGET" config core.hooksPath scripts/githooks
```
