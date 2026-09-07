# `git-worktrees`

The cross-harness worktree convention, moved out of `~/.claude/CLAUDE.md` on 2026-09-07.

## Why it is a skill and not an instruction

The convention applies at implementation only. A brainstorm, a design or a plan session never needs it, and those are most sessions. Delivering 435 words to every session to serve a minority of them is what pushed the instruction file past Antigravity's 24,023-character limit.

The trigger stays in `CLAUDE.md`, in the housekeeping section: run `git fetch` and `git worktree list` before the first command that changes branch state. That line names this skill. So the rule still fires, and the detail arrives only when it is needed.

## What it states

- The path convention `<repo>/.worktrees/<harness>/<branch>`, and the seven harness segment names.
- When a worktree is required rather than offered: more than one entry in `git worktree list`.
- Two corrections to `superpowers:using-git-worktrees`, which is an upstream clone and is never patched locally.
- Per-harness notes, and the VS Code `git.detectWorktrees` setting.

## Design note

The nested `.workbench/` case is worth keeping in the skill rather than in a guide. `git worktree list` in the outer repository reports nothing about the inner one, so an agent that checks only the outer repository draws the wrong conclusion about whether another session is live.
