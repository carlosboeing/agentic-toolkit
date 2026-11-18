# next

Answers "what's next?" with a one-line TL;DR, the next action and why, and a short progress line through the SDLC phases, plus any gap or decision waiting on you. It is for people who run many sessions at once, switch between them, and read only the top of a reply.

## How to run it

- Ask in your own words: "what's next?", "where are we?", "what now?", "status?". The agent loads the skill from its description.
- Or run it by name: `/next` in Claude Code and OpenCode, `$next` in Codex, `/skill:next` in Kimi Code. In other harnesses, ask in words.

## What the reply looks like

> **TL;DR:** Saved search filters: the parser is built, but the requirements are still a draft.
>
> **What's next:** The agent wires the parser into the search page, because the page blocks the demo. Then: saved-filter storage.
>
> **Where we are:** Requirements draft → Design skipped → **Implementation, task 2 of 4 (now)** → Review
>
> **Watch out:** No design record; the task order exists only in chat.
>
> **Needs you:** 1. Is the filter limit 20? It is marked proposed.

The reply is plain Markdown with bold labels, under about 80 words. TL;DR and What's next always appear; the others appear only when they have something to say. Watch out compares the work with its records: a draft record treated as accepted, a phase the records call for that never happened, a value still marked proposed, a passed checkpoint, and uncommitted or unpushed work.

## Why it stays cheap

- Only the description loads in every session. The body, about 900 tokens, loads when you ask.
- Most answers need no tool call, because the session already knows the work.
- In a fresh session it reads at most five sources: record frontmatter, a `Next checkpoint` line, plan checkbox counts and `git status -sb`. It never scans the repository, reads Git history or opens the tracker.

## How it differs from `/briefing`

`/briefing` is a full project orientation you run on purpose, and it never runs for "what's next?". `next` answers that one question for the current workstream. The global brief also asks every multi-turn reply to open with its phase and step, as in "Implementation, task 3 of 5", so the position is visible between `next` calls.

## Install

See [Install one skill](../README.md#install-one-skill) in the skills catalog, or run `scripts/sync-toolkit.sh --harness` to sync every skill.
