# Git hooks

These hooks run inside a target Git repository. They apply to commits and pushes made by people or agents, independent of the AI harness in use.

The separate [`hooks/`](../hooks/) directory contains harness lifecycle hooks that intercept tool calls.

## Install (shared pattern)

Each hook is versioned **inside** the target repository rather than sourced from here, so a fresh clone carries it:

```bash
hook_name=private-workbench-guard
target_repo="$HOME/src/example-repo"

mkdir -p "$target_repo/scripts/githooks"
cp "git-hooks/$hook_name/pre-commit" "$target_repo/scripts/githooks/pre-commit"
chmod +x "$target_repo/scripts/githooks/pre-commit"
git -C "$target_repo" config core.hooksPath scripts/githooks
```

`core.hooksPath` is local to each clone. Git does not copy that setting when another machine clones the repository, so configure it on every clone. Check it with `git -C "$target_repo" config --get core.hooksPath`.

## Catalog

| Hook | Event | What it does |
|---|---|---|
| [`private-workbench-guard/`](private-workbench-guard/) | `pre-commit` | Rejects a staged workbench gitlink, workbench citation, or private-side vocabulary in a public repository. |
| [`drift-guard/`](drift-guard/) | `pre-push`, `post-merge`, manual `housekeep` | Rejects stale project records before push and reports branches, worktrees, or issues left behind after a merge. |
| `copydesk` | `pre-commit` | Extracted to [`carlosboeing/copydesk`](https://github.com/carlosboeing/copydesk) on 2026-08-19, and lives in that repository's `git-hooks/`. It runs the CopyDesk suite before a commit. |

## Conventions for this type

- One directory per hook, named for what it guards rather than which event it uses.
- The script filename is the git hook name (`pre-commit`), so installing is a copy rather than a rename.
- Each directory's `README.md` states what the hook checks and what it deliberately leaves out. This prevents a later maintainer from rebuilding a rejected approach.
- Every pattern that can produce false positives is measured against real history before shipping, and the numbers go in the README. A hook that fires on legitimate commits gets bypassed reflexively, which is worse than no hook.
