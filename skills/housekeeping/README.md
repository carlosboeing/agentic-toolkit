# housekeeping

Reports what a merge left behind, then removes it. The vendored script `scripts/githooks/housekeep` does the work, and this skill calls it.

## What it does

- `/housekeeping` runs `housekeep check` and prints the findings. It always exits 0.
- `/housekeeping fix` removes the worktree and the local branch of a pull request GitHub reports as merged, then prunes stale remote refs.

## Why a script and not a skill

Three of six harnesses cannot run a blocking hook. So the enforcement lives in git. Git sees the work whoever produced it. The skill is a way to call the same script by hand.

The script is vendored per repository at `scripts/githooks/housekeep`, because `core.hooksPath` is per clone and git never sets it on clone. `/repo-standards check` reports a repository that lacks it, and `/repo-standards fix` installs it.

## What it will not do

- Delete a remote branch. No code path issues one.
- Delete anything without confirming `MERGED` through `gh` first.
- Delete a branch when its worktree has uncommitted changes.
- Run on a schedule, or from a hook. `post-merge` runs `check`, never `fix`.

## Design notes

`git branch -d` refuses after a squash merge, because git cannot see the squash as a merge. That is why `fix` uses `-D`, and why the `gh` confirmation comes first rather than last.

The pull request numbers come from commit subjects in `ORIG_HEAD..HEAD`, matched on a trailing `(#N)`. A direct push to `main` produces no number, which is correct: there is no pull request to check.

Design: [`docs/2-design/2026-09-04-repo-housekeeping-and-instruction-weight.md`](../../docs/2-design/2026-09-04-repo-housekeeping-and-instruction-weight.md).
