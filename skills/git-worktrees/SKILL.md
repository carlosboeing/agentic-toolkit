---
name: git-worktrees
description: Use before any command that changes branch state - git checkout -b, git switch -c, git worktree add - and when asked where a worktree goes, whether to branch in place, or how to recover a commit made on the wrong branch. States the cross-harness worktree path convention and the two corrections to superpowers:using-git-worktrees.
---

# Git worktrees

Every harness uses one path convention: `<repo>/.worktrees/<harness>/<branch>`. Claude Code is included, and there is no native-tool exception.

## The path

- Put worktrees inside the repository under `.worktrees/`, never in a sibling directory.
- Verify `.worktrees/` is git-ignored first, with `git check-ignore -q .worktrees/`.
- If the entry is missing, add it, create the worktree, then commit the entry from inside the new worktree rather than from the shared checkout.
- Harness segment names: `codex`, `cursor`, `agy`, `kimi`, `grok`, `opencode`, `claude`.
- Keep the branch name intact, slashes included. Branch `feat/foo` under Claude Code goes to `.worktrees/claude/feat/foo`, so `git worktree list` prints the branch name back to you.

A nested working-memory repository has its own worktrees. `.workbench/` is a separate repository, and its worktrees go under `.workbench/.worktrees/<harness>/<branch>`. The outer repository's `git worktree list` reports nothing about them.

## When to create one

Worktrees are for implementation, not for thinking. Brainstorm, discovery, design and plan work happens in the main checkout, with no branch and no worktree.

At implementation, ask before the first command that changes branch state: "Worktree, or branch in place?" Do not decide silently in either direction.

One case is not a question. If `git worktree list` prints more than one entry for the repository, another session is live in it.

A `git checkout -b` there moves HEAD for every worktree of that repository, and reverts uncommitted edits with no warning. Create the worktree and say why.

## Check for company first

Run `git worktree list` before any branch command. Run `git -C .workbench worktree list` too, where that repository exists.

## Recover, do not discard

If a commit goes to the wrong branch, confirm its content exists elsewhere before you drop it. Then rebase `--onto` the right base and push with `--force-with-lease`.

## Two corrections to the `superpowers:using-git-worktrees` skill

The upstream skill is a clone managed by `git pull`, so nobody patches it locally. Two of its steps are wrong for this setup.

1. It builds `.worktrees/<branch>` with no harness segment. Always insert the segment: `.worktrees/<harness>/<branch>`.
2. It says to commit `.gitignore` from the shared checkout when `.worktrees/` is unignored. Do not. Add the entry, create the worktree, and commit from inside it.

## Harness notes

| Harness | Rule |
|---|---|
| Claude Code | Manual convention. `EnterWorktree` is not used, because one path per harness beats two. |
| Codex CLI, Gemini CLI / Antigravity, Kimi Code | Manual convention. |
| Cursor | Manual convention, unless the project configures `worktree.json`. |
| Grok Build TUI | Native session worktrees live under `~/.grok/worktrees/`. Manual worktrees use `.worktrees/grok/<branch>`. |

An explicit worktree location in project instructions takes precedence over every rule in this skill.

## Seeing them in VS Code

Set `git.detectWorktrees` to `true`, because it defaults to `false`. Each detected worktree then appears as its own repository in Source Control, and its uncommitted changes become diffable without a second window.
