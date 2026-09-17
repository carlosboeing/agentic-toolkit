---
name: housekeeping
description: Full audit of local branches and registered worktrees against GitHub pull requests, reporting what merges left behind and removing verified stale local state. Modes: audit (default full inventory), check (last pull window), fix (refresh, recheck, and remove). Deletes locally only, never a remote branch.
---

# `/housekeeping`

The drift-guard script `scripts/githooks/housekeep` does the work. This skill calls it and prints what it returns.

## Synopsis

```
  /housekeeping              full audit of local branches and registered worktrees (default)
  /housekeeping audit        full audit of local branches and registered worktrees
  /housekeeping check        report what the last pull left behind (windowed ORIG_HEAD..HEAD)
  /housekeeping fix          refresh, recheck, and remove the audit-removable branches and worktrees
  /housekeeping help         show this synopsis
```

## How to parse the args

Walk the tokens once. The sets are closed and order does not matter.

- **Mode keywords**: `audit`, `check`, `fix`. Default: `audit`.
- **Help keywords**: `help`, `?`, `usage`, `--help`, `-h`. Any of these renders the synopsis and stops.
- **Anything else**: ignored, and say so in one line.

## audit (default)

1. Find the script. It is `scripts/githooks/housekeep` in the repository root. If it is absent, say so and stop. `/repo-standards fix` installs it.
2. If a nested `.workbench/.git` sidecar repository is present, run once per repository — root first, then sidecar — and label each block with its repository path.
3. Run `./scripts/githooks/housekeep audit` (or `(cd .workbench && ./scripts/githooks/housekeep audit)` for the sidecar).
4. Print the output as it stands. Always quote the scope line.
5. Define the repository as clean only when the full-audit scope line reports zero unresolved (`0 unresolved`) and there are no findings (0 removable, 0 kept, 0 unresolved). If output is empty, say the script failed.

The script enumerates all local branches and registered worktrees, resolves them against GitHub pull requests by commit identity, verifies destination history ancestry, and checks worktree status. It calls `gh`, so it needs the network. It always exits 0.

## check

1. Run `./scripts/githooks/housekeep check`.
2. Print the output as it stands.

`check` inspects only pull request numbers derived from `ORIG_HEAD..HEAD` (the last pull) plus stale remote refs. It always ends with a pointer to `housekeep audit`. Never report or imply the repository is clean from `check` alone: it covers only the last pull.

## fix

`fix` operates on the audit-removable set, re-evaluated fresh after refreshing destination history.

1. Run `audit` first and print it.
2. Say in one line what `fix` will delete: the named worktrees, named local branches, and stale remote refs identified as removable.
3. Run `./scripts/githooks/housekeep fix`.
4. Print the delta output (changed verdicts, deletions, prunes, post-fix inventory).
5. Repair roadmap and document findings by hand in the same task: move `## Next` roadmap lines to `## Recently shipped` and update linked documents to `status: shipped`.
6. If a `.workbench/.git` sidecar is present, repeat the audit and fix sequence for the sidecar.

`fix` fetches origin first, rechecks pull request state through `gh pr view` and local lineage before each deletion, and stops if a worktree has uncommitted changes or holds ignored files. It never force-removes a worktree and never deletes a remote branch.

## Harness notes

The script is written in Bash and runs anywhere with `git` and `gh`. Four harnesses need an explicit `rtk` prefix on shell commands: Codex, Antigravity, Kimi Code, and Grok.

A nested working-memory repository is separate. Run the script again with `(cd .workbench && ./scripts/githooks/housekeep <mode>)`, or use `git -C .workbench`.
