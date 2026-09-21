# housekeeping

Reports what a merge left behind, then removes it. The vendored script `scripts/githooks/housekeep` does the work, and this skill calls it.

## What it does

- `/housekeeping` (or `/housekeeping audit`) performs a full audit of every local branch and registered worktree against GitHub pull requests by commit identity, verifying destination history and worktree cleanliness. Always exits 0.
- `/housekeeping check` runs a windowed check over the last pull (`ORIG_HEAD..HEAD`) plus stale remote refs.
- `/housekeeping fix` refreshes origin, re-verifies each candidate against GitHub and local lineage, removes the worktree and local branch, and prunes stale remote refs.

## Why a script and not a skill

Three of six harnesses cannot run a blocking hook. So the enforcement lives in git. Git sees the work whoever produced it. The skill is a way to call the same script by hand.

The script is vendored per repository at `scripts/githooks/housekeep`, because `core.hooksPath` is per clone and git never sets it on clone. `/repo-standards check` reports a repository that lacks it, and `/repo-standards fix` installs it.

## What it will not do

- Delete a remote branch. No code path issues one.
- Force-remove a worktree (`--force`).
- Delete a branch when its worktree has uncommitted changes or holds ignored files.
- Delete a branch checked out in the main worktree or the active worktree running `fix`.
- Delete without verifying the merge commit is an ancestor of the base branch (or default branch) in destination history.
- Delete anything without confirming `MERGED` through `gh` first, both during inventory resolution and immediately before deletion.
- Delete anything if origin fetch fails during the refresh step.
- Run on a schedule, or from a hook. `post-merge` runs `check`, never `fix`.

## Design notes

`git branch -d` refuses after a squash merge, because git cannot see the squash as a merge. That is why `fix` uses `-D`, and why the `gh` confirmation and destination history verification come first.

`git worktree remove` cleanly deletes worktrees containing ignored files (such as build artifacts or local configs) without warning. `housekeep` explicitly inspects ignored files via `git status --porcelain --ignored` during `audit` and refuses deletion during `fix`.

A nested `.workbench` repository is an independent git repository. Run the skill or script separately for `.workbench` when present.

Designs:
- Full audit (2026-09-16).
- Initial merge reporter and push gate (2026-09-04).

