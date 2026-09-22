# git-worktrees

Sets one worktree convention for every AI coding harness, and the checks an agent runs before it changes branches. The agent loads it automatically before a command such as `git checkout -b`, `git switch -c` or `git worktree add`.

## What it defines

- **Where worktrees go:** `<repo>/.worktrees/<harness>/<branch>`, with a fixed folder name for each harness.
- **When a worktree is required:** if `git worktree list` shows more than one entry, another session may be active, so the agent creates a worktree instead of changing branches in place.
- **Two corrections to the `superpowers:using-git-worktrees` skill,** applied here rather than by editing that upstream skill.
- **Harness notes,** including the VS Code `git.detectWorktrees` setting.

## Why it is a skill

Worktrees matter only when implementation starts. Brainstorm, design and planning sessions never need these rules, so keeping them in the always-loaded instruction file wasted context in most sessions. The instruction file keeps a one-line trigger, run `git fetch` and `git worktree list` before changing branch state, which names this skill. The full rules load only when they apply.

## Nested private repositories

If the repository contains a nested private repository, `git worktree list` in the outer repository says nothing about the inner one. The skill tells the agent to check both. Otherwise it could wrongly conclude that no other session is working there.

## Install

See [Install one skill](../README.md#install-one-skill) in the skills catalog, or run `scripts/sync-toolkit.sh --harness` to sync every skill.
