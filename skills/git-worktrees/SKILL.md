---
name: git-worktrees
description: Use before any command that changes branch state - git checkout -b, git switch -c, git worktree add - and when asked where a worktree goes, whether to branch in place, or how to recover a commit made on the wrong branch. States the cross-harness worktree path convention and the steps to create, check, and recover worktrees.
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

Creating a branch in one worktree does not move other worktrees' HEADs or discard their edits; each worktree has its own HEAD and its own uncommitted state. The rule stands for isolation: sessions that share one working tree interleave edits and branch switches in a tree none of them owns. Create the worktree and say why.

## Check for company first

Run `git worktree list` before any branch command. Run `git -C .workbench worktree list` too, where that repository exists.

## Recover, do not discard

If a commit goes to the wrong branch, confirm its content exists elsewhere before you drop it. Then rebase `--onto` the right base and push with `--force-with-lease`.

## Create one

1. Run `git fetch`, then `git worktree list`.
2. Confirm `.worktrees/` is ignored, as above.
3. Run `git worktree add -b <branch> .worktrees/<harness>/<branch> origin/main`, branching off `origin/main` rather than a local `main` that may have diverged.
4. Work, test, and commit from inside the new worktree.

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
