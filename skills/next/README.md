# next

Answers "what's next?" with the big picture in about ten lines: the workstream, where it sits in the SDLC, the progress so far, the next action and why, and any decision waiting on you. It is for people who run many sessions at once and switch between them: the first line alone says where you are.

## How to run it

- Ask in your own words: "what's next?", "where are we?", "what now?", "status?". The agent loads the skill from its description.
- Or run it by name: `/next` in Claude Code and OpenCode, `$next` in Codex, `/skill:next` in Kimi Code. In other harnesses, ask in words.

## What the reply looks like

```
Saved search filters · Implementation, task 2 of 4

Brainstorm done → Requirements draft → Design skipped → [Implementation] → Review

Last:  filter parser done on the branch, tests pass
Next:  agent wires the parser into the search page, because the page blocks the demo
Then:  add saved-filter storage
Gaps:  requirements still draft; no design record; task order exists only in chat
Needs you:  1. Confirm the 20-filter limit (marked proposed)
```

The `Gaps` line compares what the session claims with what the records say. It reports a draft record treated as accepted, a phase the records call for that never happened, a value still marked proposed, and uncommitted or unpushed work.

## Why it stays cheap

- Only the description loads in every session. The body, about 700 tokens, loads when you ask.
- Most answers need no tool call, because the session already knows the work.
- In a fresh session it reads at most five sources: record frontmatter, a `Next checkpoint` line, plan checkbox counts and `git status -sb`. It never scans the repository, reads Git history or opens the tracker.

## How it differs from `/briefing`

`/briefing` is a full project orientation you run on purpose, and it never runs for "what's next?". `next` answers that one question for the current workstream. The global brief also asks every multi-turn reply to open with its phase and step, as in "Implementation, task 3 of 5", so the position is visible between `next` calls.

## Install

See [Install one skill](../README.md#install-one-skill) in the skills catalog, or run `scripts/sync-toolkit.sh --harness` to sync every skill.
