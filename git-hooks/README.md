# Git hooks

These hooks run inside a Git repository, on commits, pushes and merges. They apply to everyone who works in the repository, person or agent, whatever AI harness they use.

The separate [`hooks/`](../hooks/) directory holds harness hooks, which run inside an AI coding harness when the agent uses a tool.

## Catalog

| Hook | Runs on | What it does |
|---|---|---|
| [`private-workbench-guard`](private-workbench-guard/) | `pre-commit` | Stops a public repository from committing a nested private repository, citations of private documents, or private paths |
| [`drift-guard`](drift-guard/) | `pre-push`, `post-merge`, and the `housekeep` command | Stops a push when tracking records are out of date, and reports branches and worktrees left behind after a merge |

The CopyDesk commit hook that used to live here now ships with [CopyDesk](https://github.com/carlosboeing/copydesk).

## Install a hook in a repository

Each hook is committed into the target repository, so every clone carries it. Copy the hook, then point Git at the hook directory:

```bash
hook_name=private-workbench-guard
target_repo="$HOME/src/example-repo"

mkdir -p "$target_repo/scripts/githooks"
cp "git-hooks/$hook_name/pre-commit" "$target_repo/scripts/githooks/pre-commit"
chmod +x "$target_repo/scripts/githooks/pre-commit"
git -C "$target_repo" config core.hooksPath scripts/githooks
```

`core.hooksPath` is a per-clone setting. Git does not copy it when someone clones the repository, so set it on each clone. Check it with:

```bash
git -C "$target_repo" config --get core.hooksPath
```

`scripts/sync-toolkit.sh --repos` installs the hooks into every repository in your projects directory. Run it with `--dry-run` first.

## Writing a Git hook

- **Name the directory after what the hook protects,** not the Git event it uses.
- **Name the script after the Git hook,** for example `pre-commit`, so installing it is a plain copy.
- **Document what the hook leaves out on purpose.** This stops a later maintainer from rebuilding an approach that was already rejected.
- **Measure false positives before shipping.** Run each pattern against real commit history and record the numbers in the README. A hook that blocks legitimate commits gets bypassed out of habit, which is worse than having no hook.
