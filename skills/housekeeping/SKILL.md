---
name: housekeeping
description: Report what a merge left behind, then remove it. Reads the merged pull requests out of the last pull, asks GitHub which are merged, and names the branch, worktree, roadmap line and stale document each one left. Use after merging a pull request, or when a repository feels untidy. Deletes locally only, never a remote branch.
---

# `/housekeeping`

The drift-guard script `scripts/githooks/housekeep` does the work. This skill calls it and prints what it returns.

## Synopsis

```
  /housekeeping              report what the last merge left behind
  /housekeeping fix          remove the merged branch and its worktree, locally
  /housekeeping help         show this synopsis
```

## How to parse the args

Walk the tokens once. The sets are closed and order does not matter.

- **Mode keywords**: `check`, `fix`. Default: `check`.
- **Help keywords**: `help`, `?`, `usage`, `--help`, `-h`. Any of these renders the synopsis and stops.
- **Anything else**: ignored, and say so in one line.

## check

1. Find the script. It is `scripts/githooks/housekeep` in the repository root. If it is absent, say so and stop. `/repo-standards fix` installs it.
2. Run `./scripts/githooks/housekeep check`.
3. Print the output as it stands. Add nothing.
4. If the output is empty, say the repository is clean.

The script reads pull request numbers out of `ORIG_HEAD..HEAD`, so it reports on the last pull. It calls `gh`, so it needs the network. It always exits 0.

It reports four things:

1. The branch of a merged pull request, still present, and any worktree that uses it.
2. A `## Next` roadmap line naming an issue that merge closed.
3. A document linked from that line whose `status` is not `shipped`.
4. Stale remote refs that `git remote prune` would drop.

## fix

Findings 1 and 4 are the only ones `fix` acts on. Findings 2 and 3 are text you write.

1. Run `check` first and print it.
2. Say in one line what `fix` will delete: the named worktree, the named local branch, and stale remote refs.
3. Run `./scripts/githooks/housekeep fix`.
4. Print the output.
5. Repair findings 2 and 3 by hand, in the same task. Move the roadmap line to `## Recently shipped` and set the document's `status` to `shipped`.

`fix` confirms `MERGED` through `gh` before it deletes anything. It stops when a worktree has uncommitted changes. It never deletes a remote branch, from any code path.

## Harness notes

The script is written in Bash (the shell) and runs anywhere with `git` and `gh`. Four harnesses need an explicit `rtk` prefix on shell commands: Codex, Antigravity, Kimi Code and Grok.

A nested working-memory repository is separate. Run the script again with `git -C .workbench`, or from inside that directory.
